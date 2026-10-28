import 'package:graphql_schema2/graphql_schema2.dart';
part 'main.g.dart';

@graphQLClass
class TodoItem {
  @GraphQLDocumentation(typeName: #graphQLId)
  String? id;

  String? text;

  @GraphQLDocumentation(description: 'Whether this item is complete.')
  bool? isComplete;
}

void main() {
  print(todoItemGraphQLType.fields.map((f) => f.name));
}
