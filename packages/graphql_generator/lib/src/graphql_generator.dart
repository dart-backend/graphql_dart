import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:angel3_model/angel3_model.dart';
import 'package:angel3_serialize_generator/angel3_serialize_generator.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:graphql_generator2/src/graphql_literal.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';

/// Generates GraphQL schemas, statically.
Builder graphQLBuilder(_) {
  return SharedPartBuilder([_GraphQLGenerator()], 'graphql_generator2');
}

var _docComment = RegExp(r'^/// ', multiLine: true);
var _graphQLDoc = TypeChecker.typeNamed(GraphQLDocumentation);
var _graphQLClassTypeChecker = TypeChecker.typeNamed(GraphQLClass);

class _GraphQLGenerator extends GeneratorForAnnotation<GraphQLClass> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is ClassElement) {
      var ctx = await buildContext(
        element,
        annotation,
        buildStep,
        buildStep.resolver,
        serializableTypeChecker.hasAnnotationOf(element),
      );

      var lib = _buildClassSchemaLibrary(element, ctx, annotation);

      return lib.accept(DartEmitter()).toString();
    }

    if (element is EnumElement) {
      var lib = _buildEnumSchemaLibrary(element, annotation);

      return lib.accept(DartEmitter()).toString();
    }

    throw UnsupportedError(
      '@GraphQLClass() is only supported on classes or enums.',
    );
  }

  bool isInterface(ClassElement clazz) {
    return clazz.isAbstract && !serializableTypeChecker.hasAnnotationOf(clazz);
  }

  bool _isGraphQLClass(InterfaceType clazz) {
    InterfaceType? search = clazz;

    while (search != null) {
      if (_graphQLClassTypeChecker.hasAnnotationOf(search.element)) {
        return true;
      }

      search = search.superclass;
    }

    return false;
  }

  /// A reference to the generated GraphQL type of [type]. A `@serializable`
  /// model's type is named after its generated class, as `todoGraphQLType` of
  /// `TodoEntity` or `_Todo`. The element's name is used, as the type's display
  /// string has a `?` when it is nullable.
  Expression _graphQLTypeOf(InterfaceType type) {
    var name = type.element.displayName;
    if (serializableTypeChecker.hasAnnotationOf(type.element)) {
      name = generatedClassNameOf(name);
    }

    return refer('${ReCase(name).camelCase}GraphQLType');
  }

  Expression _inferType(String className, String name, DartType type) {
    // Firstly, check if it's a GraphQL class.
    if (type is InterfaceType && _isGraphQLClass(type)) {
      return _graphQLTypeOf(type);
    }

    var primitive = {
      String: 'graphQLString',
      int: 'graphQLInt',
      double: 'graphQLFloat',
      bool: 'graphQLBoolean',
      DateTime: 'graphQLDate',
    };

    // Check to see if it's a primitive type.
    for (var entry in primitive.entries) {
      if (TypeChecker.typeNamed(entry.key).isAssignableFromType(type)) {
        return refer(entry.value);
      }
    }

    // Next, check to see if it's a List.
    if (type is InterfaceType &&
        type.typeArguments.isNotEmpty &&
        TypeChecker.typeNamed(Iterable).isAssignableFromType(type)) {
      var arg = type.typeArguments[0];
      var inner = _inferType(className, name, arg);

      return refer('listOf').call([inner]);
    }

    // Nothing else is allowed.
    throw 'Cannot infer the GraphQL type for field $className.$name (type=$type).';
  }

  /// The code for a field's resolved value, read with [getter]. A GraphQL enum
  /// is matched by name, so an enum value, or a list of them, becomes names.
  String _resolvedValue(String getter, DartType type) {
    String q(DartType t) =>
        t.nullabilitySuffix == NullabilitySuffix.question ? '?' : '';

    if (type.element is EnumElement) return '$getter${q(type)}.name';

    if (type is InterfaceType &&
        type.typeArguments.length == 1 &&
        type.typeArguments.single.element is EnumElement &&
        TypeChecker.typeNamed(Iterable).isAssignableFromType(type)) {
      var item = type.typeArguments.single;
      return '$getter${q(type)}.map((e) => e${q(item)}.name).toList()';
    }

    return getter;
  }

  void _applyDescription(
    Map<String, Expression> named,
    Element element,
    String? docComment,
  ) {
    var docString = docComment;

    if (docString == null && _graphQLDoc.hasAnnotationOf(element)) {
      var ann = _graphQLDoc.firstAnnotationOf(element);
      var cr = ConstantReader(ann);

      docString = cr.peek('description')?.stringValue;
    }

    if (docString != null) {
      named['description'] = literalString(
        docString.replaceAll(_docComment, '').replaceAll('\n', '\\n'),
      );
    }
  }

  Library _buildEnumSchemaLibrary(EnumElement clazz, ConstantReader ann) {
    return Library((b) {
      // Generate a top-level xGraphQLType object
      b.body.add(
        Field((b) {
          // enumTypeFromStrings(String name, List<String> values, {String description}
          var args = <Expression>[literalString(clazz.displayName)];
          var values = clazz.firstFragment.fields
              .where((f) => f.element.isEnumConstant)
              .map((f) => f.name);
          var named = <String, Expression>{};

          _applyDescription(named, clazz, clazz.documentationComment);

          args.add(
            literalConstList(values.map<Expression>(literalString2).toList()),
          );

          b
            ..name = '${ReCase(clazz.displayName).camelCase}GraphQLType'
            ..docs.add('/// Auto-generated from [${clazz.displayName}].')
            ..type = TypeReference(
              (b) => b
                ..symbol = 'GraphQLEnumType'
                ..types.add(refer('String')),
            )
            ..modifier = FieldModifier.final$
            ..assignment = refer('enumTypeFromStrings').call(args, named).code;
        }),
      );
    });
  }

  Library _buildClassSchemaLibrary(
    ClassElement clazz,
    BuildContext? ctx,
    ConstantReader ann,
  ) {
    return Library((b) {
      // Generate a top-level xGraphQLType object

      b.body.add(
        Field((b) {
          var args = <Expression>[literalString(ctx!.modelClassName!)];
          var named = <String, Expression>{
            'isInterface': literalBool(isInterface(clazz)),
          };

          // Add documentation
          _applyDescription(named, clazz, clazz.documentationComment);

          // Add interfaces
          var interfaces = clazz.interfaces
              .where(_isGraphQLClass)
              .map(_graphQLTypeOf);

          named['interfaces'] = literalList(interfaces);

          // Add fields
          var ctxFields = ctx.fields.toList();

          // Also incorporate parent fields.
          //TODO: To be reviewed later
          InterfaceType? search = clazz.thisType; //.type;

          while (search != null &&
              !TypeChecker.typeNamed(Object).isExactlyType(search)) {
            for (var field in search.element.fields) {
              // Skip computed getters (such as `Model.idAsInt`), which have
              // no stored value to resolve.
              if (!field.isOriginGetterSetter &&
                  !ctxFields.any((f) => f.name == field.name)) {
                ctxFields.add(field);
              }
            }

            search = search.superclass;
          }

          var fields = <Expression>[];

          for (var field in ctxFields) {
            var named = <String, Expression>{};
            var originalField = clazz.fields.firstWhereOrNull(
              (f) => f.name == field.name,
            );

            // Annotations are on the field when it is declared as a field, and
            // on the getter when it is declared as a getter (as in a
            // `@serializable` model), so look for them on both.
            var candidates = <Element>[
              ?originalField,
              ?originalField?.getter,
              field,
            ];
            Element annotatedWith(TypeChecker checker) => candidates.firstWhere(
              checker.hasAnnotationOf,
              orElse: () => candidates.first,
            );

            // Check if it is deprecated.
            var depAnn = TypeChecker.typeNamed(Deprecated).firstAnnotationOf(
              annotatedWith(TypeChecker.typeNamed(Deprecated)),
            );

            if (depAnn != null) {
              var dep = ConstantReader(depAnn);
              var reason =
                  dep.peek('message')?.stringValue ??
                  dep.peek('expires')?.stringValue ??
                  'Expires: ${deprecated.message}.';

              named['deprecationReason'] = literalString(reason);
            }

            // Description finder...
            var docEl = annotatedWith(_graphQLDoc);
            _applyDescription(
              named,
              docEl,
              originalField?.getter?.documentationComment ??
                  originalField?.documentationComment,
            );

            // Pick the type.
            var doc = _graphQLDoc.firstAnnotationOf(docEl);

            Expression? type;

            if (doc != null) {
              var cr = ConstantReader(doc);
              var typeName = cr.peek('typeName')?.objectValue.toSymbolValue();

              if (typeName != null) {
                type = refer(typeName);
              }
            }

            // The "id" field of a `Model` is an ID.
            if (field.displayName == 'id' &&
                TypeChecker.typeNamed(Model)
                    .isAssignableFromType(clazz.thisType)) {
              type ??= refer('graphQLId');
            }

            // Resolve the field from a model object; a Map is read by the
            // server before the resolver is called.
            named['resolve'] = CodeExpression(
              Code(
                '(obj, _) => ${_resolvedValue('(obj as ${clazz.displayName}).${field.displayName}', field.type)}',
              ),
            );

            // The resolver returns the getter's value, which may be null or a
            // model object, rather than the field type's Dart value.
            fields.add(
              refer('field').call(
                [
                  literalString(ctx.resolveFieldName(field.displayName)!),
                  type ??= _inferType(
                    clazz.displayName,
                    field.displayName,
                    field.type,
                  ),
                ],
                named,
                [refer('dynamic'), refer('dynamic')],
              ),
            );
          }

          named['fields'] = literalList(fields);

          b
            ..name = '${ctx.modelClassNameRecase.camelCase}GraphQLType'
            ..docs.add('/// Auto-generated from [${ctx.modelClassName}].')
            //..style = refer('GraphQLObjectType')
            ..type = refer('GraphQLObjectType')
            ..modifier = FieldModifier.final$
            ..assignment = refer('objectType').call(args, named).code;
        }),
      );
    });
  }
}
