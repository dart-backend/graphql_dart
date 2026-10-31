import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_validate/server.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:graphql_parser2/graphql_parser2.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';

final ContentType graphQlContentType = ContentType('application', 'graphql');

final Validator graphQlPostBody = Validator({
  'query*': isNonEmptyString,
  'operationName': isNonEmptyString,
  // The name it was read by before 10.0.0, still accepted.
  'operation_name': isNonEmptyString,
  'variables': predicate((dynamic v) => v == null || v is String || v is Map),
});

final RegExp _num = RegExp(r'^[0-9]+$');

/// Puts [file] at [path], such as `variables.files.0`, of the multipart
/// request's [variables], replacing the `null` there.
void _setFile(Map<String, dynamic> variables, Object? path, UploadedFile file) {
  if (path is! String || !path.startsWith('variables.')) {
    throw AngelHttpException.badRequest(
      message:
          'All array values in the "map" field must begin with "variables.".',
    );
  }
  var names = path.split('.').skip(1).toList();
  Object? current = variables;
  for (var (i, name) in names.indexed) {
    var parent = ['variables', ...names.take(i)].join('.');
    var last = i == names.length - 1;
    if (current is List && _num.hasMatch(name)) {
      var index = int.parse(name);
      if (index >= current.length) {
        throw AngelHttpException.badRequest(
          message: 'The array "$parent" has no index $index.',
        );
      }
      if (last) {
        current[index] = file;
      } else {
        current = current[index];
      }
    } else if (current is Map) {
      if (last) {
        current[name] = file;
      } else {
        current = current[name];
      }
    } else {
      throw AngelHttpException.badRequest(
        message:
            'The "map" field contained a mapping to $parent.$name, but '
            '"$parent" is not a JSON object or array.',
      );
    }
  }
}

/// A [RequestHandler] that serves a spec-compliant GraphQL backend.
///
/// Follows the guidelines listed here:
/// https://graphql.org/learn/serving-over-http/
RequestHandler graphQLHttp(
  GraphQL graphQL, {
  Function(RequestContext, ResponseContext, Stream<Map<String, dynamic>>)?
  onSubscription,
}) {
  return (req, res) async {
    var globalVariables = <String, dynamic>{
      '__requestctx': req,
      '__responsectx': res,
    };

    Future sendGraphQLResponse(result) async {
      if (result is Stream<Map<String, dynamic>>) {
        if (onSubscription == null) {
          throw StateError(
            'The GraphQL backend returned a Stream, but no `onSubscription` callback was provided.',
          );
        } else {
          return await onSubscription(req, res, result);
        }
      }

      return {'data': result};
    }

    /// Runs the request of [map], a request body or the query parameters of
    /// a GET: its `query`, `operationName` and `variables`, which may be a
    /// JSON string.
    Future executeMap(Map map, {Map<String, dynamic>? variables}) async {
      var text = map['query'];
      if (text is! String) {
        throw AngelHttpException.badRequest(
          message: 'Missing a string "query".',
        );
      }
      var operationName = map['operationName'] ?? map['operation_name'];
      if (operationName != null && operationName is! String) {
        throw AngelHttpException.badRequest(
          message: '"operationName" must be a string.',
        );
      }
      if (variables == null) {
        var given = map['variables'];
        if (given is String) given = given.isEmpty ? null : json.decode(given);
        if (given != null && given is! Map) {
          throw AngelHttpException.badRequest(
            message: '"variables" must be a JSON object.',
          );
        }
        variables = foldToStringDynamic(given as Map?);
      }

      return await sendGraphQLResponse(
        await graphQL.parseAndExecute(
          text,
          sourceUrl: 'input',
          operationName: operationName as String?,
          variableValues: variables,
          globalVariables: globalVariables,
        ),
      );
    }

    /// Runs a request of the GraphQL multipart request specification: its
    /// `operations` are a JSON object of `query`, `operationName` and
    /// `variables`, and its `map` gives, for each uploaded file, the paths in
    /// `variables` to put it at.
    ///
    /// See: https://github.com/jaydenseric/graphql-multipart-request-spec
    Future executeMultipart() async {
      var fields = await req.parseBody().then((_) => req.bodyAsMap);
      var operations = fields['operations'];
      if (operations is! String) {
        throw AngelHttpException.badRequest(
          message: 'Missing "operations" field.',
        );
      }
      var operation = json.decode(operations);
      if (operation is! Map) {
        throw AngelHttpException.badRequest(
          message: '"operations" field must decode to a JSON object.',
        );
      }
      var given = operation['variables'];
      if (given != null && given is! Map) {
        throw AngelHttpException.badRequest(
          message: 'The "variables" of "operations" must be a JSON object.',
        );
      }
      var variables = foldToStringDynamic(given as Map?);

      var map = fields.containsKey('map')
          ? json.decode(fields['map'] as String)
          : const {};
      if (map is! Map) {
        throw AngelHttpException.badRequest(
          message: '"map" field must decode to a JSON object.',
        );
      }
      for (var MapEntry(:key, :value) in map.entries) {
        var file = req.uploadedFiles?.firstWhereOrNull((f) => f.name == key);
        if (file == null) {
          throw AngelHttpException.badRequest(
            message:
                '"map" contained key "$key", but no uploaded file has that '
                'name.',
          );
        }
        if (value is! List) {
          throw AngelHttpException.badRequest(
            message:
                'The value for "$key" in the "map" field was not a JSON array.',
          );
        }
        for (var path in value) {
          _setFile(variables, path, file);
        }
      }

      return await executeMap(operation, variables: variables);
    }

    try {
      if (req.method == 'GET') {
        if (await validateQuery(graphQlPostBody)(req, res) as bool) {
          return await executeMap(req.queryParameters);
        }
      } else if (req.method == 'POST') {
        if (req.headers!.contentType?.mimeType == graphQlContentType.mimeType) {
          var text = await utf8.decoder.bind(req.body!).join();
          return await sendGraphQLResponse(
            await graphQL.parseAndExecute(
              text,
              sourceUrl: 'input',
              globalVariables: globalVariables,
            ),
          );
        } else if (req.headers!.contentType?.mimeType == 'application/json') {
          if (await validate(graphQlPostBody)(req, res) as bool) {
            return await executeMap(req.bodyAsMap);
          }
        } else if (req.headers!.contentType?.mimeType ==
            'multipart/form-data') {
          return await executeMultipart();
        } else {
          throw AngelHttpException.badRequest();
        }
      } else {
        throw AngelHttpException.badRequest();
      }
    } on ValidationException catch (e) {
      var errors = <GraphQLExceptionError>[GraphQLExceptionError(e.message)];

      errors.addAll(e.errors.map((ee) => GraphQLExceptionError(ee)).toList());
      return GraphQLException(errors).toJson();
    } on AngelHttpException catch (e) {
      var errors = <GraphQLExceptionError>[GraphQLExceptionError(e.message)];

      errors.addAll(e.errors.map((ee) => GraphQLExceptionError(ee)).toList());
      return GraphQLException(errors).toJson();
    } on SyntaxError catch (e) {
      return GraphQLException.fromSourceSpan(e.message, e.span!);
    } on GraphQLException catch (e) {
      return e.toJson();
    } catch (e, st) {
      if (req.app?.logger != null) {
        req.app!.logger.severe(
          'An error occurred while processing GraphQL query at ${req.uri}.',
          e,
          st,
        );
      }

      return GraphQLException.fromMessage(e.toString()).toJson();
    }
  };
}
