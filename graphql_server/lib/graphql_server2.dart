import 'dart:async';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:graphql_parser2/graphql_parser2.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
import 'introspection.dart';

/// Transforms any [Map] into `Map<String, dynamic>`.
Map<String, dynamic> foldToStringDynamic(Map? map) {
  if (map == null) {
    return {};
  }
  return map.keys.fold<Map<String, dynamic>>(
      <String, dynamic>{}, (out, k) => out..[k.toString()] = map[k]);
}

class JsonPathArgument {
  JsonPathArgument(
      this.path, this.definition, this.defaultValue, this.variableValues)
      : _spl = path.split('.') {
    if (_spl.isEmpty || _spl.length < 2 || _spl.first != r'$') {
      throw 'Bad json path $path';
    }

    _spl.removeAt(0);
  }

  final String path;
  final Map<String, dynamic> variableValues;
  final List<String> _spl;
  final dynamic defaultValue;
  Iterable<String> get splitted => _spl;
  final VariableDefinitionContext definition;

  void complete(dynamic value) {
    variableValues[definition.variable.name] = value ?? defaultValue;
  }
}

/// A Dart implementation of a GraphQL server.
class GraphQL {
  /// Any custom types to include in introspection information.
  final List<GraphQLType> customTypes = [];

  /// An optional callback that can be used to resolve fields from objects that are not [Map]s,
  /// when the related field has no resolver.
  final FutureOr<T> Function<T>(T, String?, Map<String, dynamic>)?
      defaultFieldResolver;

  GraphQLSchema _schema;

  GraphQL(GraphQLSchema schema,
      {bool introspect = true,
      this.defaultFieldResolver,
      List<GraphQLType> customTypes = const <GraphQLType>[]})
      : _schema = schema {
    if (customTypes.isNotEmpty == true) {
      this.customTypes.addAll(customTypes);
    }

    var allTypes = fetchAllTypes(schema, [...this.customTypes]);

    if (introspect) {
      _schema = reflectSchema(_schema, allTypes);
    }

    for (var type in allTypes.toSet()) {
      if (!this.customTypes.contains(type)) {
        if (type != null) {
          this.customTypes.add(type);
        }
      }
    }

    if (_schema.queryType != null) {
      this.customTypes.add(_schema.queryType!);
    }
    if (_schema.mutationType != null) {
      this.customTypes.add(_schema.mutationType!);
    }
    if (_schema.subscriptionType != null) {
      this.customTypes.add(_schema.subscriptionType!);
    }
  }

  GraphQLType convertType(TypeContext ctx,
      {bool usePolymorphicName = false, GraphQLObjectType? parent}) {
    var listType = ctx.listType;
    var typeName = ctx.typeName;
    if (listType != null) {
      var convert = convertType(listType.innerType);
      return GraphQLListType(convert);
    } else if (typeName != null) {
      final name = typeName.name;

      switch (name) {
        case 'Int':
          return graphQLInt;
        case 'Float':
          return graphQLFloat;
        case 'String':
          return graphQLString;
        case 'Boolean':
          return graphQLBoolean;
        case 'ID':
          return graphQLId;
        case 'Date':
        case 'DateTime':
          return graphQLDate;
        default:
          usePolymorphicName = usePolymorphicName && parent != null;

          if (usePolymorphicName) {
            final ret = customTypes.firstWhereOrNull((t) {
              return t is GraphQLObjectType &&
                  t.polymorphicName == name &&
                  parent.possibleTypes.contains(t);
            });

            if (ret != null) {
              return ret;
            }
          }

          return customTypes.firstWhere((t) {
            return t.name == name;
          },
              orElse: () =>
                  throw ArgumentError('Unknown GraphQL type: "$name"'));
      }
    } else {
      throw ArgumentError('Invalid GraphQL type: "${ctx.span.text}"');
    }
  }

  Future parseAndExecute(String text,
      {String? operationName,
      sourceUrl,
      Map<String, dynamic> variableValues = const {},
      initialValue,
      Map<String, dynamic> globalVariables = const {}}) {
    var tokens = scan(text, sourceUrl: sourceUrl);
    var parser = Parser(tokens);
    var document = parser.parseDocument();

    if (parser.errors.isNotEmpty) {
      throw GraphQLException(parser.errors
          .map((e) => GraphQLExceptionError(e.message, locations: [
                GraphExceptionErrorLocation.fromSourceLocation(e.span!.start)
              ]))
          .toList());
    }

    return executeRequest(
      _schema,
      document,
      operationName: operationName,
      initialValue: initialValue,
      variableValues: variableValues,
      globalVariables: globalVariables,
    );
  }

  Future executeRequest(GraphQLSchema schema, DocumentContext document,
      {String? operationName,
      Map<String, dynamic> variableValues = const <String, dynamic>{},
      initialValue,
      Map<String, dynamic> globalVariables = const <String, dynamic>{}}) async {
    var operation = getOperation(document, operationName);
    var coercedVariableValues =
        coerceVariableValues(schema, operation, variableValues);
    if (operation.isQuery) {
      return await executeQuery(document, operation, schema,
          coercedVariableValues, initialValue, globalVariables);
    } else if (operation.isSubscription) {
      return await subscribe(document, operation, schema, coercedVariableValues,
          globalVariables, initialValue);
    } else {
      return executeMutation(document, operation, schema, coercedVariableValues,
          initialValue, globalVariables);
    }
  }

  OperationDefinitionContext getOperation(
      DocumentContext document, String? operationName) {
    var ops = document.definitions.whereType<OperationDefinitionContext>();
    if (operationName == null) {
      return ops.length == 1
          ? ops.first
          : throw GraphQLException.fromMessage(
              'This document does not define any operations.');
    } else {
      return ops.firstWhere((d) => d.name == operationName,
          orElse: (() => throw GraphQLException.fromMessage(
              'Missing required operation "$operationName".')));
    }
  }

  Map<String, dynamic> coerceVariableValues(
      GraphQLSchema schema,
      OperationDefinitionContext operation,
      Map<String, dynamic> variableValues) {
    var coercedValues = <String, dynamic>{};
    var variableDefinitions =
        operation.variableDefinitions?.variableDefinitions ?? [];

    for (var variableDefinition in variableDefinitions) {
      var variableName = variableDefinition.variable.name;
      var variableType = variableDefinition.type;
      var defaultValue = variableDefinition.defaultValue;

      //if (variableName == null) {
      //  continue;
      //}
      var value = variableValues[variableName];
      dynamic toSet;

      final jp = getDirectiveValue(
          'jsonpath', 'path', variableDefinition, variableValues);

      if (value == null) {
        if (defaultValue != null) {
          toSet = defaultValue.value.computeValue(variableValues);
        } else if (!variableType.isNullable && jp == null) {
          throw GraphQLException.fromSourceSpan(
              'Missing required variable "$variableName".',
              variableDefinition.span);
        }
      } else {
        var type = convertType(variableType);
        var validation = type.validate(variableName, value);

        if (!validation.successful) {
          throw GraphQLException(validation.errors
              .map((e) => GraphQLExceptionError(e, locations: [
                    GraphExceptionErrorLocation.fromSourceLocation(
                        variableDefinition.span.start)
                  ]))
              .toList());
        } else {
          toSet = type.deserialize(value);
        }
      }

      if (jp != null) {
        toSet = JsonPathArgument(jp, variableDefinition, toSet, coercedValues);
      }

      coercedValues[variableName] = toSet;
    }

    return coercedValues;
  }

  List<List> makeLazy(Map<String, dynamic> map) {
    final lazy = <List>[];

    for (final val in map.values) {
      if (val is JsonPathArgument) {
        lazy.add([...val.splitted, val]);
      } else if (val is Map) {
        makeLazy(map);
      }
    }

    return lazy;
  }

  Future<Map<String, dynamic>> executeQuery(
      DocumentContext document,
      OperationDefinitionContext query,
      GraphQLSchema schema,
      Map<String, dynamic> variableValues,
      initialValue,
      Map<String, dynamic> globalVariables) async {
    var queryType = schema.queryType;
    var selectionSet = query.selectionSet;

    return await executeSelectionSet(document, selectionSet, queryType,
        initialValue, variableValues, globalVariables,
        lazy: makeLazy(variableValues));
  }

  Future<Map<String?, dynamic>> executeMutation(
      DocumentContext document,
      OperationDefinitionContext mutation,
      GraphQLSchema schema,
      Map<String, dynamic> variableValues,
      initialValue,
      Map<String, dynamic> globalVariables) async {
    var mutationType = schema.mutationType;

    if (mutationType == null) {
      throw GraphQLException.fromMessage(
          'The schema does not define a mutation type.');
    }

    var selectionSet = mutation.selectionSet;
    return await executeSelectionSet(document, selectionSet, mutationType,
        initialValue, variableValues, globalVariables,
        lazy: makeLazy(variableValues));
  }

  Future<Stream<Map<String, dynamic>>> subscribe(
      DocumentContext document,
      OperationDefinitionContext subscription,
      GraphQLSchema schema,
      Map<String, dynamic> variableValues,
      Map<String, dynamic> globalVariables,
      initialValue) async {
    var sourceStream = await createSourceEventStream(
        document, subscription, schema, variableValues, initialValue);
    return mapSourceToResponseEvent(sourceStream, subscription, schema,
        document, initialValue, variableValues, globalVariables);
  }

  Future<Stream> createSourceEventStream(
      DocumentContext document,
      OperationDefinitionContext subscription,
      GraphQLSchema schema,
      Map<String?, dynamic> variableValues,
      initialValue) {
    var selectionSet = subscription.selectionSet;
    var subscriptionType = schema.subscriptionType;
    if (subscriptionType == null) {
      throw GraphQLException.fromSourceSpan(
          'The schema does not define a subscription type.',
          subscription.span!);
    }
    var groupedFieldSet =
        collectFields(document, subscriptionType, selectionSet, variableValues);
    if (groupedFieldSet.length != 1) {
      throw GraphQLException.fromSourceSpan(
          'The grouped field set from this query must have exactly one entry.',
          selectionSet.span!);
    }
    var fields = groupedFieldSet.entries.first.value;
    var fieldName = fields.first.field!.fieldName.alias?.name ??
        fields.first.field!.fieldName.name;
    var field = fields.first;
    var argumentValues =
        coerceArgumentValues(subscriptionType, field, variableValues);
    return resolveFieldEventStream(
        subscriptionType, initialValue, fieldName, argumentValues);
  }

  Stream<Map<String, dynamic>> mapSourceToResponseEvent(
    Stream sourceStream,
    OperationDefinitionContext subscription,
    GraphQLSchema schema,
    DocumentContext document,
    initialValue,
    Map<String, dynamic> variableValues,
    Map<String, dynamic> globalVariables,
  ) async* {
    await for (var event in sourceStream) {
      yield await executeSubscriptionEvent(document, subscription, schema,
          event, variableValues, globalVariables);
    }
  }

  Future<Map<String, dynamic>> executeSubscriptionEvent(
      DocumentContext document,
      OperationDefinitionContext subscription,
      GraphQLSchema schema,
      initialValue,
      Map<String, dynamic> variableValues,
      Map<String, dynamic> globalVariables) async {
    var selectionSet = subscription.selectionSet;
    var subscriptionType = schema.subscriptionType;
    if (subscriptionType == null) {
      throw GraphQLException.fromSourceSpan(
          'The schema does not define a subscription type.',
          subscription.span!);
    }
    try {
      var data = await executeSelectionSet(document, selectionSet,
          subscriptionType, initialValue, variableValues, globalVariables,
          lazy: makeLazy(variableValues));
      return {'data': data};
    } on GraphQLException catch (e) {
      return {
        'data': null,
        'errors': [e.errors.map((e) => e.toJson()).toList()]
      };
    }
  }

  Future<Stream> resolveFieldEventStream(GraphQLObjectType subscriptionType,
      rootValue, String? fieldName, Map<String, dynamic> argumentValues) async {
    var field = subscriptionType.fields.firstWhere((f) => f.name == fieldName,
        orElse: () {
      throw GraphQLException.fromMessage(
          'No subscription field named "$fieldName" is defined.');
    });
    var resolver = field.resolve!;
    var result = await resolver(rootValue, argumentValues);
    if (result is Stream) {
      return result;
    } else {
      return Stream.fromIterable([result]);
    }
  }

  Future<Map<String, dynamic>> executeSelectionSet(
    DocumentContext document,
    SelectionSetContext selectionSet,
    GraphQLObjectType? objectType,
    objectValue,
    Map<String, dynamic> variableValues,
    Map<String, dynamic> globalVariables, {
    List<List> lazy = const [],
    GraphQLObjectType? parentType,
  }) async {
    var groupedFieldSet = collectFields(
        document, objectType!, selectionSet, variableValues,
        parentType: parentType);
    var resultMap = <String, dynamic>{};

    for (var responseKey in groupedFieldSet.keys) {
      if (responseKey == null) {
        continue;
      }

      final nextLazy = <List>[];
      final doneLazy = <List>[];

      for (final l in lazy) {
        if (l.first == responseKey) {
          final key = l.elementAt(0);
          final arr = l..removeAt(0);

          if (l.length > 1) {
            nextLazy.add(arr);
          } else {
            doneLazy.add([key, ...arr]);
          }
        }
      }

      final fields = groupedFieldSet[responseKey] ?? [];

      for (var field in fields) {
        var fieldName =
            field.field?.fieldName.alias?.name ?? field.field?.fieldName.name;
        FutureOr futureResponseValue;

        if (fieldName == '__typename') {
          futureResponseValue = objectType.name;
        } else {
          final fieldType = objectType.fields
              .firstWhereOrNull((f) => f.name == fieldName)
              ?.type;

          if (fieldType == null) {
            continue;
          }

          futureResponseValue = executeField(
              document,
              fieldName,
              objectType,
              objectValue,
              fields,
              fieldType,
              Map<String, dynamic>.from(globalVariables)
                ..addAll(variableValues),
              globalVariables,
              lazy: nextLazy.toList());
        }

        final val = resultMap[responseKey] = await futureResponseValue;

        for (final lz in doneLazy) {
          if (lz.first as String == responseKey) {
            (lz.last as JsonPathArgument).complete(val);
          }
        }
      }

      //final map = resultMap[responseKey];
    }

    return resultMap;
  }

  Future executeField(
      DocumentContext document,
      String? fieldName,
      GraphQLObjectType objectType,
      dynamic objectValue,
      List<SelectionContext> fields,
      GraphQLType fieldType,
      Map<String, dynamic> variableValues,
      Map<String, dynamic> globalVariables,
      {List<List> lazy = const []}) async {
    var field = fields[0];
    var argumentValues =
        coerceArgumentValues(objectType, field, variableValues);
    var resolvedValue = await resolveFieldValue(
        objectType,
        objectValue,
        fieldName,
        Map<String, dynamic>.from(globalVariables)..addAll(argumentValues));
    return completeValue(document, fieldName, fieldType, fields, resolvedValue,
        variableValues, globalVariables,
        lazy: lazy);
  }

  Map<String, dynamic> coerceArgumentValues(GraphQLObjectType objectType,
      SelectionContext field, Map<String?, dynamic> variableValues) {
    var coercedValues = <String, dynamic>{};
    var argumentValues = field.field?.arguments;
    var fieldName =
        field.field?.fieldName.alias?.name ?? field.field?.fieldName.name;
    var desiredField = objectType.fields.firstWhere((f) => f.name == fieldName,
        orElse: (() => throw FormatException(
            '${objectType.name} has no field named "$fieldName".')));
    var argumentDefinitions = desiredField.inputs;

    for (var argumentDefinition in argumentDefinitions) {
      var argumentName = argumentDefinition.name;
      var argumentType = argumentDefinition.type;
      var defaultValue = argumentDefinition.defaultValue;

      var argumentValue =
          argumentValues?.firstWhereOrNull((a) => a.name == argumentName);

      if (argumentValue == null) {
        if (defaultValue != null || argumentDefinition.defaultsToNull) {
          coercedValues[argumentName] = defaultValue;
        } else if (argumentType is GraphQLNonNullableType) {
          throw GraphQLException.fromMessage(
              'Missing value for argument "$argumentName" of field "$fieldName".');
        } else {
          continue;
        }
      } else {
        final inputValue = argumentValue.value
            .computeValue(variableValues as Map<String, dynamic>);

        try {
          final validation = argumentType.validate(argumentName, inputValue);

          if (!validation.successful) {
            var errors = <GraphQLExceptionError>[
              GraphQLExceptionError(
                'Type coercion error for value of argument "$argumentName" of field "$fieldName". ($inputValue)',
                locations: [
                  GraphExceptionErrorLocation.fromSourceLocation(
                      argumentValue.value.span!.start)
                ],
              )
            ];

            for (var error in validation.errors) {
              var err = argumentValue.value.span?.start;
              var locations = <GraphExceptionErrorLocation>[];
              if (err != null) {
                locations
                    .add(GraphExceptionErrorLocation.fromSourceLocation(err));
              }
              errors.add(
                GraphQLExceptionError(
                  error,
                  locations: locations,
                ),
              );
            }

            throw GraphQLException(errors);
          } else {
            final coercedValue = argumentType.deserialize(inputValue);

            coercedValues[argumentName] = coercedValue;
          }
        } on TypeError catch (e) {
          var err = argumentValue.value.span?.start;
          var locations = <GraphExceptionErrorLocation>[];
          if (err != null) {
            locations.add(GraphExceptionErrorLocation.fromSourceLocation(err));
          }

          throw GraphQLException(<GraphQLExceptionError>[
            GraphQLExceptionError(
              'Type coercion error for value of argument "$argumentName" of field "$fieldName". [$inputValue]',
              locations: locations,
            ),
            GraphQLExceptionError(
              e.toString(),
              locations: locations,
            ),
          ]);
        }
      }
    }

    return coercedValues;
  }

  Future<T?> resolveFieldValue<T>(GraphQLObjectType objectType, T objectValue,
      String? fieldName, Map<String, dynamic> argumentValues) async {
    final field = objectType.fields.firstWhere((f) => f.name == fieldName);
    final fieldResolve = field.resolve;

    if (objectValue is Map) {
      return objectValue[fieldName] as T;
    } else if (fieldResolve == null) {
      if (defaultFieldResolver != null) {
        return await defaultFieldResolver!(
            objectValue, fieldName, argumentValues);
      }
      return null;
    } else {
      return await fieldResolve(objectValue, argumentValues) as T?;
    }
  }

  Future completeValue(
      DocumentContext document,
      String? fieldName,
      GraphQLType fieldType,
      List<SelectionContext> fields,
      dynamic result,
      Map<String, dynamic> variableValues,
      Map<String, dynamic> globalVariables,
      {List<List> lazy = const []}) async {
    if (fieldType is GraphQLNonNullableType) {
      var innerType = fieldType.ofType;
      var completedResult = await completeValue(document, fieldName, innerType,
          fields, result, variableValues, globalVariables);

      if (completedResult == null) {
        throw GraphQLException.fromMessage(
            'Null value provided for non-nullable field "$fieldName".');
      } else {
        return completedResult;
      }
    }

    if (result == null) {
      return null;
    }

    if (fieldType is GraphQLListType) {
      if (result is! Iterable) {
        throw GraphQLException.fromMessage(
            'Value of field "$fieldName" must be a list or iterable, got $result instead.');
      }

      var innerType = fieldType.ofType;
      var futureOut = [];

      for (var resultItem in result) {
        futureOut.add(completeValue(document, '(item in "$fieldName")',
            innerType, fields, resultItem, variableValues, globalVariables));
      }

      var out = [];
      for (var f in futureOut) {
        out.add(await f);
      }

      return out;
    }

    if (fieldType is GraphQLScalarType) {
      try {
        final ret = fieldType.serialize(result);

        return ret;
      } on TypeError {
        throw GraphQLException.fromMessage(
            'Value of field "$fieldName" must be ${fieldType.valueType}, got $result (${result.runtimeType}) instead.');
      }
    }

    if (fieldType is GraphQLObjectType || fieldType is GraphQLUnionType) {
      GraphQLObjectType objectType;

      if (fieldType is GraphQLObjectType && !fieldType.isInterface) {
        objectType = fieldType;
      } else {
        objectType = resolveAbstractType(fieldName, fieldType, result);
      }

      //objectType = fieldType as GraphQLObjectType;
      var subSelectionSet = mergeSelectionSets(fields);
      return await executeSelectionSet(document, subSelectionSet, objectType,
          result, variableValues, globalVariables,
          lazy: lazy, parentType: fieldType as GraphQLObjectType);
    }

    throw UnsupportedError('Unsupported type: $fieldType');
  }

  GraphQLObjectType resolveAbstractType(
      String? fieldName, GraphQLType type, dynamic result) {
    List<GraphQLObjectType> possibleTypes;

    if (type is GraphQLObjectType) {
      if (type.isInterface) {
        possibleTypes = type.possibleTypes;
      } else {
        return type;
      }
    } else if (type is GraphQLUnionType) {
      possibleTypes = type.possibleTypes;
    } else {
      throw ArgumentError();
    }

    final errors = <GraphQLExceptionError>[];
    final types = [];

    for (var t in possibleTypes) {
      try {
        var validation =
            t.validate(fieldName!, foldToStringDynamic(result as Map?));

        if (validation.successful) {
          types.add(t);
        } else {
          errors.addAll(validation.errors.map((m) => GraphQLExceptionError(m)));
        }
      } on GraphQLException catch (e) {
        errors.addAll(e.errors);
      }
    }

    if (types.isNotEmpty) {
      if (types.length == 1) {
        return types.first;
      } else if (type is GraphQLObjectType) {
        return type;
      }
    }

    errors.insert(0,
        GraphQLExceptionError('Cannot convert value $result to type $type.'));

    throw GraphQLException(errors);
  }

  SelectionSetContext mergeSelectionSets(List<SelectionContext> fields) {
    var selections = <SelectionContext>[];

    for (var field in fields) {
      if (field.field?.selectionSet != null) {
        selections.addAll(field.field!.selectionSet!.selections);
      } else if (field.inlineFragment?.selectionSet != null) {
        selections.addAll(field.inlineFragment!.selectionSet.selections);
      }
    }

    return SelectionSetContext.merged(selections);
  }

  Map<String?, List<SelectionContext>> collectFields(
      DocumentContext document,
      GraphQLObjectType? objectType,
      SelectionSetContext selectionSet,
      Map<String?, dynamic> variableValues,
      {List? visitedFragments,
      GraphQLObjectType? parentType}) {
    var groupedFields = <String?, List<SelectionContext>>{};
    visitedFragments ??= [];

    for (var selection in selectionSet.selections) {
      final field = selection.field;

      if (field != null) {
        if (getDirectiveValue('skip', 'if', field, variableValues) == true) {
          continue;
        }
        if (getDirectiveValue('include', 'if', field, variableValues) ==
            false) {
          continue;
        }
      }

      if (selection.field != null) {
        var responseKey = selection.field!.fieldName.alias?.alias ??
            selection.field!.fieldName.name;
        var groupForResponseKey =
            groupedFields.putIfAbsent(responseKey, () => []);
        groupForResponseKey.add(selection);
      } else if (selection.fragmentSpread != null) {
        var fragmentSpreadName = selection.fragmentSpread!.name;
        if (visitedFragments.contains(fragmentSpreadName)) continue;
        visitedFragments.add(fragmentSpreadName);
        var fragment = document.definitions
            .whereType<FragmentDefinitionContext>()
            .firstWhereOrNull((f) => f.name == fragmentSpreadName);

        if (fragment == null) continue;
        var fragmentType = fragment.typeCondition;
        if (!doesFragmentTypeApply(objectType, fragmentType)) continue;
        var fragmentSelectionSet = fragment.selectionSet;
        var fragmentGroupFieldSet = collectFields(
            document, objectType, fragmentSelectionSet, variableValues);

        for (var responseKey in fragmentGroupFieldSet.keys) {
          var fragmentGroup = fragmentGroupFieldSet[responseKey]!;
          var groupForResponseKey =
              groupedFields.putIfAbsent(responseKey, () => []);
          groupForResponseKey.addAll(fragmentGroup);
        }
      } else if (selection.inlineFragment != null) {
        var fragmentType = selection.inlineFragment!.typeCondition;
        if (!doesFragmentTypeApply(objectType, fragmentType,
            parentType: parentType)) continue;
        var fragmentSelectionSet = selection.inlineFragment!.selectionSet;
        var fragmentGroupFieldSet = collectFields(
            document, objectType, fragmentSelectionSet, variableValues);

        for (var responseKey in fragmentGroupFieldSet.keys) {
          var fragmentGroup = fragmentGroupFieldSet[responseKey]!;
          var groupForResponseKey =
              groupedFields.putIfAbsent(responseKey, () => []);
          groupForResponseKey.addAll(fragmentGroup);
        }
      }
    }

    return groupedFields;
  }

  dynamic getDirectiveValue(String name, String argumentName, Directives holder,
      Map<String?, dynamic> variableValues) {
    var directive = holder.directives.firstWhereOrNull((d) {
      var vv = d.value;

      if (vv is VariableContext) {
        return vv.name == name;
      } else if (vv == null) {
        return d.nameToken?.text == name;
      } else {
        return vv.computeValue(variableValues as Map<String, dynamic>) == name;
      }
    });

    if (directive == null) return null;
    if (directive.argument?.name != argumentName) return null;

    var vv = directive.argument!.value;
    if (vv is VariableContext) {
      var vname = vv.name;
      if (!variableValues.containsKey(vname)) {
        throw GraphQLException.fromSourceSpan(
            'Unknown variable: "$vname"', vv.span);
      }
      return variableValues[vname];
    }
    return vv.computeValue(variableValues as Map<String, dynamic>);
  }

  bool doesFragmentTypeApply(
      GraphQLObjectType? objectType, TypeConditionContext fragmentType,
      {GraphQLObjectType? parentType}) {
    var type = convertType(TypeContext(fragmentType.typeName, null),
        usePolymorphicName: true, parent: parentType ?? objectType);
    if (type is GraphQLObjectType && !type.isInterface) {
      for (var field in type.fields) {
        if (!objectType!.fields.any((f) => f.name == field.name)) return false;
      }
      return true;
    } else if (type is GraphQLObjectType && type.isInterface) {
      return objectType!.isImplementationOf(type);
    } else if (type is GraphQLUnionType) {
      return type.possibleTypes.any((t) => objectType!.isImplementationOf(t));
    }

    return false;
  }
}
