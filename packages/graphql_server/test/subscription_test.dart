import 'dart:async';

import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:test/test.dart';

void main() {
  var episodes = [
    {'name': 'The Phantom Menace'},
    {'name': 'Attack of the Clones'},
    {'name': 'Attack of the Clones'},
  ];
  var episodesAsData = episodes.map((ep) {
    return {
      'data': {'prequels': ep},
    };
  });

  Stream<Map<String, dynamic>> resolveEpisodes(_, _) =>
      Stream.fromIterable(episodes)
          .map((ep) => {'prequels': ep, 'not_selected': 1337});

  var episodeType = objectType(
    'Episode',
    fields: [
      field('name', graphQLString.nonNullable()),
      field('not_selected', graphQLInt),
    ],
  );

  var schema = graphQLSchema(
    queryType: objectType(
      'TestQuery',
      fields: [field('episodes', graphQLInt, resolve: (_, _) => episodes)],
    ),
    subscriptionType: objectType(
      'TestSubscription',
      fields: [field('prequels', episodeType, resolve: resolveEpisodes)],
    ),
  );

  var graphQL = GraphQL(schema);

  test('subscribe with selection', () async {
    var stream = await graphQL.parseAndExecute('''
    subscription {
      prequels {
        name
      }
    }
    ''') as Stream<Map<String, dynamic>>;

    var asList = await stream.toList();
    print(asList);
    expect(asList, episodesAsData);
  });

  test('cancelling a subscription stops its source at once', () async {
    var cancelled = Completer<void>();
    var source = StreamController<int>(onCancel: cancelled.complete);
    var graphQL = GraphQL(
      graphQLSchema(
        queryType: objectType('Q', fields: [field('a', graphQLInt)]),
        subscriptionType: objectType(
          'S',
          fields: [
            field(
              'n',
              graphQLInt,
              resolve: (_, _) => source.stream.map((n) => {'n': n}),
            ),
          ],
        ),
      ),
    );
    var stream = await graphQL.parseAndExecute('subscription { n }') as Stream;
    var subscription = stream.listen(null);
    await Future<void>.delayed(Duration.zero);
    // No event has come, so the source is cancelled without one.
    await subscription.cancel();
    await cancelled.future.timeout(const Duration(seconds: 1));
  });

  test('the errors of a failed event are a list of errors', () async {
    var graphQL = GraphQL(
      graphQLSchema(
        queryType: objectType('Q', fields: [field('a', graphQLInt)]),
        subscriptionType: objectType(
          'S',
          fields: [
            field(
              'n',
              graphQLInt.nonNullable(),
              resolve: (_, _) => Stream.value({'n': null}),
            ),
          ],
        ),
      ),
    );
    var stream = await graphQL.parseAndExecute('subscription { n }') as Stream;
    var event = await stream.first as Map;
    expect(event['data'], isNull);
    expect(event['errors'], [
      isA<Map>().having((e) => e['message'], 'message', isA<String>()),
    ]);
  });
}
