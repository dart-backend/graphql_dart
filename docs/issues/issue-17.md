# Issue 17

When working with GraphiQL, usually a number of queries are written down in the same document for convenience:

query todos {
  todos {
    id
    text
  }
}

mutation add {
  createTodo(data: { text: "dqwdwq" }) {
    id
  }
}

However, when trying to execute any of the queries, the GraphiQL sends the whole document to the server containing every operation out there, the one to run is sent via operationName parameter:

operationName: "add"
query: "query todos {\n  todos {\n    id\n    text\n  }\n}\n\nmutation add {\n  createTodo(data: {text: \"dqwdwq\"}) {\n    id\n  }\n}\n"
variables: {}

graphql_server2 doesn't handle such scenarios and prints the This document does not define any operations error due to this code:

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

The appropriate solution would be to respect the operationName and find the operation with the specified name in the ops list, not throw an error if there's more than 1 (or less than 1) operation - error should be thrown if there's 0 operations in the document of the specified operationName doesn't correspond to any provided.