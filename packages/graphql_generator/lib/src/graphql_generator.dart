import 'dart:async';
import 'dart:mirrors';
import 'package:analyzer/dart/element/element2.dart';
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
var _graphQLDoc = TypeChecker.fromRuntime(GraphQLDocumentation);
var _graphQLClassTypeChecker = TypeChecker.fromRuntime(GraphQLClass);

class _GraphQLGenerator extends GeneratorForAnnotation<GraphQLClass> {
  @override
  Future<String> generateForAnnotatedElement(
    Element2 element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is ClassElement2) {
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

    if (element is EnumElement2) {
      var lib = _buildEnumSchemaLibrary(element, annotation);

      return lib.accept(DartEmitter()).toString();
    }

    throw UnsupportedError(
      '@GraphQLClass() is only supported on classes or enums.',
    );
  }

  bool isInterface(ClassElement2 clazz) {
    return clazz.isAbstract && !serializableTypeChecker.hasAnnotationOf(clazz);
  }

  bool _isGraphQLClass(InterfaceType clazz) {
    InterfaceType? search = clazz;

    while (search != null) {
      if (_graphQLClassTypeChecker.hasAnnotationOf(search.element3)) {
        return true;
      }

      search = search.superclass;
    }

    return false;
  }

  Expression _inferType(String className, String name, DartType type) {
    // Firstly, check if it's a GraphQL class.
    if (type is InterfaceType && _isGraphQLClass(type)) {
      var c = type;
      var name =
          serializableTypeChecker.hasAnnotationOf(c.element3) &&
              c.getDisplayString().startsWith('_')
          ? c.getDisplayString().substring(1)
          : c.getDisplayString();
      var rc = ReCase(name);

      return refer('${rc.camelCase}GraphQLType');
    }

    // Next, check if this is the "id" field of a `Model`.
    if (TypeChecker.fromRuntime(Model).isAssignableFromType(type) &&
        name == 'id') {
      return refer('graphQLId');
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
      if (TypeChecker.fromRuntime(entry.key).isAssignableFromType(type)) {
        return refer(entry.value);
      }
    }

    // Next, check to see if it's a List.
    if (type is InterfaceType &&
        type.typeArguments.isNotEmpty &&
        TypeChecker.fromRuntime(Iterable).isAssignableFromType(type)) {
      var arg = type.typeArguments[0];
      var inner = _inferType(className, name, arg);

      return refer('listOf').call([inner]);
    }

    // Nothing else is allowed.
    throw 'Cannot infer the GraphQL type for field $className.$name (type=$type).';
  }

  void _applyDescription(
    Map<String, Expression> named,
    Element2 element,
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

  Library _buildEnumSchemaLibrary(EnumElement2 clazz, ConstantReader ann) {
    return Library((b) {
      // Generate a top-level xGraphQLType object
      b.body.add(
        Field((b) {
          // enumTypeFromStrings(String name, List<String> values, {String description}
          var args = <Expression>[literalString(clazz.displayName)];
          var values = clazz.firstFragment.fields2
              .where((f) => f.element.isEnumConstant)
              .map((f) => f.name2);
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
    ClassElement2 clazz,
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
          var interfaces = clazz.interfaces.where(_isGraphQLClass).map((c) {
            var name =
                serializableTypeChecker.hasAnnotationOf(c.element3) &&
                    c.getDisplayString().startsWith('_')
                ? c.getDisplayString().substring(1)
                : c.getDisplayString();
            var rc = ReCase(name);

            return refer('${rc.camelCase}GraphQLType');
          });

          named['interfaces'] = literalList(interfaces);

          // Add fields
          var ctxFields = ctx.fields.toList();

          // Also incorporate parent fields.
          //TODO: To be reviewed later
          InterfaceType? search = clazz.thisType; //.type;

          while (search != null &&
              !TypeChecker.fromRuntime(Object).isExactlyType(search)) {
            for (var field in search.element3.fields2) {
              if (!ctxFields.any((f) => f.name3 == field.name3)) {
                ctxFields.add(field);
              }
            }

            search = search.superclass;
          }

          var fields = <Expression>[];

          for (var field in ctxFields) {
            var named = <String, Expression>{};
            var originalField = clazz.fields2.firstWhereOrNull(
              (f) => f.name3 == field.name3,
            );

            // Check if it is deprecated.
            var depEl = originalField?.getter2 ?? originalField ?? field;
            var depAnn = TypeChecker.fromRuntime(
              Deprecated,
            ).firstAnnotationOf(depEl);

            if (depAnn != null) {
              var dep = ConstantReader(depAnn);
              var reason =
                  dep.peek('messages')?.stringValue ??
                  dep.peek('expires')?.stringValue ??
                  'Expires: ${deprecated.message}.';

              named['deprecationReason'] = literalString(reason);
            }

            // Description finder...
            _applyDescription(
              named,
              originalField?.getter2 ?? originalField ?? field,
              originalField?.getter2?.documentationComment ??
                  originalField?.documentationComment,
            );

            // Pick the type.
            var doc = _graphQLDoc.firstAnnotationOf(depEl);

            Expression? type;

            if (doc != null) {
              var cr = ConstantReader(doc);
              var typeName = cr.peek('typeName')?.symbolValue;

              if (typeName != null) {
                type = refer(MirrorSystem.getName(typeName));
              }
            }

            fields.add(
              refer('field').call([
                literalString(ctx.resolveFieldName(field.displayName)!),
                type ??= _inferType(
                  clazz.displayName,
                  field.displayName,
                  field.type,
                ),
              ], named),
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
