import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
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

/// [name], a Dart or GraphQL name, which goes into a generated string, with its
/// `$`s escaped, as a Dart name may hold one. A name holds no backslash or
/// quote to escape.
String _noInterpolation(String name) => name.replaceAll(r'$', r'\$');
var _graphQLDoc = TypeChecker.typeNamed(GraphQLDocumentation);

/// `SerializableField`, and `Exclude`, which extends it, of `angel3_serialize`.
const _serializableField = TypeChecker.fromUrl(
  'package:angel3_serialize/angel3_serialize.dart#SerializableField',
);

/// Whether [field] is left out of serialization by an annotation on it, or on
/// its getter: `@SerializableField(exclude: true)` or `@exclude`, unless it
/// may still be serialized. Read here, as the serializer's context records
/// exclusions only of the fields it serializes, which a `final` field is not.
bool _isExcluded(FieldElement field) {
  for (var element in <Element>[field, ?field.getter]) {
    for (var annotation in _serializableField.annotationsOf(element)) {
      var reader = ConstantReader(annotation);
      if (reader.peek('exclude')?.boolValue == true &&
          reader.peek('canSerialize')?.boolValue != true) {
        return true;
      }
    }
  }
  return false;
}

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
      named['description'] = literalString2(
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
          var args = <Expression>[literalString2(clazz.displayName)];
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
          var args = <Expression>[literalString2(ctx!.modelClassName!)];
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
            // Static and private fields are not the model's data (and a
            // private one of another library cannot be read), and a field the
            // serializer leaves out, such as a password hash, must not be
            // given out either.
            if (field.isStatic ||
                field.isPrivate ||
                ctx.excluded[field.name]?.canSerialize == false ||
                _isExcluded(field)) {
              continue;
            }

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

              named['deprecationReason'] = literalString2(reason);
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
            // server before the resolver is called. An enum value is given as
            // it is, for the field's GraphQL enum type to name. Another value
            // is a GraphQL error, not a TypeError, which would fail the
            // request.
            // A null parent is null, as the server resolves it without a
            // resolver. The message names the generated class, which users
            // return, rather than a private entity class it extends.
            var graphQLName = ctx.resolveFieldName(field.displayName)!;
            var modelName = _noInterpolation(ctx.modelClassName!);
            var message =
                'Cannot resolve field "${_noInterpolation(graphQLName)}" of '
                '"$modelName" from a value of type \${obj.runtimeType}: '
                'expected a Map or an instance of $modelName.';
            named['resolve'] = CodeExpression(
              Code(
                '(obj, _) => obj is ${clazz.displayName} '
                '? obj.${field.displayName} '
                ': obj == null '
                '? null '
                ": throw GraphQLException.fromMessage('$message')",
              ),
            );

            // The resolver returns the getter's value, which may be null or a
            // model object, rather than the field type's Dart value.
            fields.add(
              refer('field').call(
                [
                  literalString2(graphQLName),
                  type ??
                      _inferType(
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
