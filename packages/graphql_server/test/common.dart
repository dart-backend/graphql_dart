import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:test/test.dart';

final Matcher throwsAGraphQLException = throwsA(
  predicate((dynamic x) => x is GraphQLException, 'is a GraphQL exception'),
);
