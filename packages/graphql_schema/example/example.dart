import 'package:graphql_schema2/graphql_schema2.dart';

final GraphQLSchema todoSchema = GraphQLSchema(
  queryType: objectType(
    'Todo',
    fields: [
      field('text', graphQLString.nonNullable(), resolve: resolveToNull),
      field('created_at', graphQLDate, resolve: resolveToNull),
    ],
  ),
);

void main() {
  // Validation
  var validation = todoSchema.queryType!.validate('@root', {
    'foo': 'bar',
    'text': null,
    'created_at': 24,
  });

  if (validation.successful) {
    print('This is valid data!!!');
  } else {
    print('Invalid data.');
    for (var s in validation.errors) {
      print('  * $s');
    }
  }

  // Serialization
  print(
    todoSchema.queryType!.serialize({
      'text': 'Clean your room!',
      'created_at': DateTime.now().subtract(Duration(days: 10)),
    }),
  );
}
