// Inspired by:
// https://www.apollographql.com/docs/apollo-server/features/subscriptions/#subscriptions-example

import 'package:angel3_file_service/angel3_file_service.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_graphql/angel3_graphql.dart';
import 'package:file/local.dart';
import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:logging/logging.dart';

void main() async {
  var logger = Logger('angel_graphql');
  var app = Angel(logger: logger);
  var http = AngelHttp(app);
  app.logger.onRecord.listen((rec) {
    print(rec);
    if (rec.error != null) print(rec.error);
    if (rec.stackTrace != null) print(rec.stackTrace);
  });

  // Create an in-memory service.
  var fs = LocalFileSystem();
  var postService =
      app.use('/api/posts', JsonFileService(fs.file('posts.json')));

  // Also get a [Stream] of item creation events.
  var postAdded = postService.afterCreated
      .asStream()
      .map((e) => {'postAdded': e.result})
      .asBroadcastStream();

  // GraphQL setup.
  var postType = objectType('Post', fields: [
    field('author', graphQLString),
    field('comment', graphQLString),
  ]);

  var schema = graphQLSchema(
    // Hooked up to the postService:
    // type Query { posts: [Post] }
    queryType: objectType(
      'Query',
      fields: [
        field(
          'posts',
          listOf(postType),
          resolve: resolveViaServiceIndex(postService),
        ),
      ],
    ),

    // Hooked up to the postService:
    // type Mutation {
    //  addPost(author: String!, comment: String!): Post
    // }
    mutationType: objectType(
      'Mutation',
      fields: [
        field(
          'addPost',
          postType,
          inputs: [
            GraphQLFieldInput(
                'data', postType.toInputObject('PostInput').nonNullable()),
          ],
          resolve: resolveViaServiceCreate(postService),
        ),
      ],
    ),

    // Hooked up to `postAdded`:
    // type Subscription { postAdded: Post }
    subscriptionType: objectType(
      'Subscription',
      fields: [
        field('postAdded', postType, resolve: (_, __) => postAdded),
      ],
    ),
  );

  // Mount GraphQL routes; we'll support HTTP and WebSockets transports.
  app.all('/graphql', graphQLHttp(GraphQL(schema)));
  app.get('/subscriptions',
      graphQLWS(GraphQL(schema), keepAliveInterval: Duration(seconds: 3)));
  app.get('/graphiql',
      graphiQL(subscriptionsEndpoint: 'ws://localhost:3000/subscriptions'));

  var server = await http.startServer('127.0.0.1', 3000);
  var uri =
      Uri(scheme: 'http', host: server.address.address, port: server.port);
  var graphiqlUri = uri.replace(path: 'graphiql');
  var postsUri = uri.replace(pathSegments: ['api', 'posts']);
  print('Listening at $uri');
  print('Access graphiql at $graphiqlUri');
  print('Access posts service at $postsUri');
}
