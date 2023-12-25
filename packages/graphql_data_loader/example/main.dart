import 'dart:async';
import 'package:graphql_data_loader2/graphql_data_loader2.dart';
import 'package:graphql_schema2/graphql_schema2.dart';

external Future<List<Todo>> fetchTodos(Iterable<int?> ids);

void main() async {
  // Create a DataLoader. By default, it caches lookups.
  var todoLoader = DataLoader(fetchTodos); // DataLoader<int, Todo>

  // type Todo { id: Int, text: String, is_complete: Boolean }
  var todoType = objectType(
    'Todo',
    fields: [
      field('id', graphQLInt),
      field('text', graphQLString),
      field('is_complete', graphQLBoolean),
    ],
  );

  // type Query { todo($id: Int!) Todo }
  // ignore: unused_local_variable
  var schema = graphQLSchema(
    queryType: objectType(
      'Query',
      fields: [
        field(
          'todo',
          listOf(todoType),
          inputs: [GraphQLFieldInput('id', graphQLInt.nonNullable())],
          resolve: (_, args) => todoLoader.load(args['id'] as int?),
        ),
      ],
    ),
  );

  // Do something with your schema...
}

abstract class Todo {
  int get id;
  String get text;
  bool get isComplete;
}
