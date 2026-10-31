# Issue 3

Is it possible to declare GQL schema in a way that allows returning model objects from query resolvers and serialize them into json later down the line? Let's say I have:

@graphQLClass
@serializable
abstract class _Todo extends Model {
  String? get text;

  bool? get isComplete;
}

and now I'd like my resolver to only care about what model data to return back:

final todo = Todo(
  id: '1',
  text: 'Mock Todo',
  isComplete: true,
  createdAt: DateTime.now().subtract(Duration(days: 3)),
  updatedAt: DateTime.now().subtract(Duration(days: 1)),
);

field(
  'todo',
  todoGraphQLType,
  resolve: (_, __) {
    return todo;
  },
  inputs: [
    GraphQLFieldInput('id', graphQLString.nonNullable()),
  ],
)

If I try to run todo query it returns:

{
  "data": {
    "todo": {
      "id": null,
      "text": null,
      "is_complete": null,
      "created_at": null,
      "updated_at": null,
      "idAsInt": null
    }
  }
}

Looks like this is because generated todoGraphQLType fields don't specify resolve parameter in which case resolveFieldValue returns null:
https://github.com/dukefirehawk/graphql_dart/blob/master/graphql_server/lib/graphql_server2.dart#L612

/// Auto-generated from [Todo].
final GraphQLObjectType todoGraphQLType =
    objectType('Todo', isInterface: false, interfaces: [], fields: [
  field('id', graphQLString),
  field('created_at', graphQLDate),
  field('updated_at', graphQLDate),
  field('text', graphQLString),
  field('is_complete', graphQLBoolean),
  field('idAsInt', graphQLInt)
]);

If I try to manually edit generated file to resolve e.g. id value and declare generic type arguments, I get static analysis error because generic type args of type parameters don't match anymore:

field<String?, Todo>(
  'id',
  // The argument type 'GraphQLScalarType<String, String>' can't be assigned to the parameter type 'GraphQLType<String?, Todo>'.
  graphQLString,
  resolve: (serialized, argumentValues) {
    return serialized.id;
  },
)

Is what I'm trying to achieve possible to implement using Angel? I have a feeling that I'm missing some important part here.