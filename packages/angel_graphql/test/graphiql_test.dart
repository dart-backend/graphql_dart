import 'package:angel3_graphql/angel3_graphql.dart';
import 'package:test/test.dart';

void main() {
  test('loads pinned scripts, checked by integrity', () {
    var page = renderGraphiql();
    for (var script in [
      'react@18.3.1/umd/react.production.min.js',
      'react-dom@18.3.1/umd/react-dom.production.min.js',
      'graphiql@4.1.2/graphiql.min.js',
      'graphiql@4.1.2/graphiql.min.css',
    ]) {
      expect(page, contains('https://unpkg.com/$script'));
    }
    expect(RegExp('integrity="sha384-').allMatches(page), hasLength(4));
    expect(page, contains('GraphiQL.createFetcher(options)'));
    expect(page, isNot(contains('subscriptions-transport-ws')));
  });

  test('gives its endpoints as JSON', () {
    var page = renderGraphiql(
      graphqlEndpoint: "/graph'ql",
      subscriptionsEndpoint: '/subscriptions</script><script>alert(1)',
    );
    expect(
      page,
      contains(
        r'var graphqlEndpoint = "/graph'
        "'"
        r'ql";',
      ),
    );
    expect(page, isNot(contains('</script><script>alert(1)')));
    expect(page, contains(r'\u003c/script\u003e'));
  });

  test('has no subscriptions endpoint by default', () {
    expect(renderGraphiql(), contains('var subscriptionsEndpoint = null;'));
  });
}
