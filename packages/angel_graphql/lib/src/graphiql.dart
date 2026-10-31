import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:http_parser/http_parser.dart';

/// Returns a simple [RequestHandler] that renders the GraphiQL visual interface for GraphQL.
///
/// By default, the interface expects your backend to be mounted at `/graphql`; this is configurable
/// via [graphQLEndpoint].
///
/// With a [subscriptionsEndpoint], such as one served by `graphQLWS`, GraphiQL
/// runs subscriptions over WebSockets, with the `graphql-transport-ws`
/// protocol. It may be a `ws://` or `wss://` URL, or a path such as
/// `/subscriptions`, of the page's host.
RequestHandler graphiQL({
  String graphQLEndpoint = '/graphql',
  String? subscriptionsEndpoint,
}) {
  return (req, res) {
    res
      ..contentType = MediaType('text', 'html')
      ..write(
        renderGraphiql(
          graphqlEndpoint: graphQLEndpoint,
          subscriptionsEndpoint: subscriptionsEndpoint,
        ),
      )
      ..close();
  };
}

/// The GraphiQL page of [graphiQL].
///
/// It loads GraphiQL 4 and React 18 from unpkg, pinned to exact versions and
/// checked by their integrity hashes; GraphiQL's own script includes the
/// `graphql-ws` client it runs subscriptions with.
String renderGraphiql({
  String graphqlEndpoint = '/graphql',
  String? subscriptionsEndpoint,
}) {
  // Written as JSON, so that an endpoint cannot break out of the script.
  String js(String? value) =>
      json.encode(value).replaceAll('<', r'\u003c').replaceAll('>', r'\u003e');

  return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Angel GraphQL</title>
    <link rel="stylesheet" href="https://unpkg.com/graphiql@4.1.2/graphiql.min.css"
          integrity="sha384-1el1QShFBnnXTx9x/Cprg82hZWKt0ry29OAYIXt05swbi0KcZDFoj0CWguMpopJr"
          crossorigin="anonymous">
    <style>
        html, body {
            margin: 0;
            padding: 0;
        }
        html, body, #app {
            height: 100%;
        }
    </style>
</head>
<body>
<div id="app"></div>
<script src="https://unpkg.com/react@18.3.1/umd/react.production.min.js"
        integrity="sha384-DGyLxAyjq0f9SPpVevD6IgztCFlnMF6oW/XQGmfe+IsZ8TqEiDrcHkMLKI6fiB/Z"
        crossorigin="anonymous"></script>
<script src="https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js"
        integrity="sha384-gTGxhz21lVGYNMcdJOyq01Edg0jhn/c22nsx0kyqP0TxaV5WVdsSH1fSDUf5YJj1"
        crossorigin="anonymous"></script>
<script src="https://unpkg.com/graphiql@4.1.2/graphiql.min.js"
        integrity="sha384-9XdHu7ajgGJziD4J1zNBKQ842Q/+zZfDv+ib1eMhZWBH6hPAs806x+Jbcf0yNO6B"
        crossorigin="anonymous"></script>
<script>
    var graphqlEndpoint = ${js(graphqlEndpoint)};
    var subscriptionsEndpoint = ${js(subscriptionsEndpoint)};
    var options = {url: new URL(graphqlEndpoint, location.href).href};
    if (subscriptionsEndpoint) {
        // A path is of the page's host, over ws: or wss: as the page is.
        var url = new URL(subscriptionsEndpoint, location.href);
        if (url.protocol === 'http:') url.protocol = 'ws:';
        if (url.protocol === 'https:') url.protocol = 'wss:';
        options.subscriptionUrl = url.href;
    }
    ReactDOM.createRoot(document.getElementById('app')).render(
        React.createElement(GraphiQL, {fetcher: GraphiQL.createFetcher(options)})
    );
</script>
</body>
</html>
'''
      .trim();
}
