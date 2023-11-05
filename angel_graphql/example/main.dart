// ignore_for_file: deprecated_member_use
import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_graphql/angel3_graphql.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:graphql_server2/mirrors.dart';
import 'package:logging/logging.dart';

void main() async {
  var logger = Logger('angel3_graphql');
  var app = Angel(
      reflector: MirrorsReflector(),
      logger: logger
        ..onRecord.listen((rec) {
          print(rec);
          if (rec.error != null) print(rec.error);
          if (rec.stackTrace != null) print(rec.stackTrace);
        }));
  var http = AngelHttp(app);

  var todoService = app.use('api/todos', MapService());

  var queryType = objectType(
    'Query',
    description: 'A simple API that manages your to-do list.',
    fields: [
      field(
        'todos',
        listOf(convertDartType(Todo)!.nonNullable()),
        resolve: resolveViaServiceIndex(todoService),
      ),
      field(
        'todo',
        convertDartType(Todo)!,
        resolve: resolveViaServiceRead(todoService),
        inputs: [
          GraphQLFieldInput('id', graphQLId.nonNullable()),
        ],
      ),
    ],
  );

  var mutationType = objectType(
    'Mutation',
    description: 'Modify the to-do list.',
    fields: [
      field(
        'createTodo',
        convertDartType(Todo)!,
        inputs: [
          GraphQLFieldInput(
              'data', convertDartType(Todo)!.coerceToInputObject()),
        ],
        resolve: resolveViaServiceCreate(todoService),
      ),
    ],
  );

  var schema = graphQLSchema(
    queryType: queryType,
    mutationType: mutationType,
  );

  app.all('/graphql', graphQLHttp(GraphQL(schema)));
  app.get('/graphiql', graphiQL());

  await todoService
      .create({'text': 'Clean your room!', 'completion_status': 'COMPLETE'});
  await todoService.create(
      {'text': 'Take out the trash', 'completion_status': 'INCOMPLETE'});
  await todoService.create({
    'text': 'Become a billionaire at the age of 5',
    'completion_status': 'INCOMPLETE'
  });

  var server = await http.startServer('127.0.0.1', 3000);
  var uri =
      Uri(scheme: 'http', host: server.address.address, port: server.port);
  var graphiqlUri = uri.replace(path: 'graphiql');
  print('Listening at $uri');
  print('Access graphiql at $graphiqlUri');
}

@GraphQLDocumentation(description: 'Any object with a .text (String) property.')
abstract class HasText {
  String? get text;
}

@serializable
@GraphQLDocumentation(
    description: 'A task that might not be completed yet. **Yay! Markdown!**')
class Todo extends Model implements HasText {
  @override
  String? text;

  @GraphQLDocumentation(deprecationReason: 'Use `completion_status` instead.')
  bool? completed;

  CompletionStatus? completionStatus;

  Todo({this.text, this.completed, this.completionStatus});
}

@GraphQLDocumentation(description: 'The completion status of a to-do item.')
enum CompletionStatus { COMPLETE, INCOMPLETE }
