# Issue 12

The following request with a nested data structure leads to an exception:

mutation invite($invitation: EventInput!) {
  push_invitation(event: $invitation)
}

# Variables:
{
  "invitation": {
      "name": "Cool event",
      "secret": "1234"
  }
}

This is the actual result which gets returned:

{
  "errors": [
    {
      "message": "Stack Overflow"
    }
  ]
}

This is the expected result:

{
  "data": {
    "push_invitation": true
  }
}

The stack trace of the exception is as follows:

flutter: Stack Overflow
flutter: #0      GraphQL.makeLazy (package:graphql_server2/graphql_server2.dart:254:3)
#1      GraphQL.makeLazy (package:graphql_server2/graphql_server2.dart:261:9)
#2      GraphQL.makeLazy (package:graphql_server2/graphql_server2.dart:261:9)
#3      GraphQL.makeLazy (package:graphql_server2/graphql_server2.dart:261:9)
...
#9328   GraphQL.makeLazy (package:graphql_server2/graphql_server2.dart:261:9)
#9329   GraphQL.makeLazy (package:graphql_server2/graphql_server2.dart:261:9)
#9330   GraphQL.makeLazy (package:graphql_server2/graphql_server2.dart:261:9)
#9331   GraphQL.executeMutation (package:graphql_server2/graphql_server2.dart:300:15)
#9332   GraphQL.executeRequest (package:graphql_server2/graphql_server2.dart:178:14)
#9333   GraphQL.parseAndExecute (package:graphql_server2/graphql_server2.dart:153:12)
#9334   graphQLHttp.<anonymous closure>.executeMap (package:angel3_graphql/src/graphql_http.dart:59:54)
#9335   _rootRunUnary (dart:async/zone.dart:1399:47)
#9336   _CustomZone.runUnary (dart:async/zone.dart:1300:19)
#9337   _FutureListener.handleValue (dart:async/future_impl.dart:147:18)
#9338   Future._propagateToListeners.handleValueCallback (dart:async/future_impl.dart:766:45)
#9339   Future._propagateToListeners (dart:async/future_impl.dart:795:13)
#9340   Future._addListener.<anonymous closure> (dart:async/future_impl.dart:430:9)
#9341   _rootRun (dart:async/zone.dart:1391:13)
#9342   _CustomZone.run (dart:async/zone.dart:1293:19)
#9343   _CustomZone.runGuarded (dart:async/zone.dart:1201:7)
#9344   _CustomZone.bindCallbackGuarded.<anonymous closure> (dart:async/zone.dart:1241:23)
#9345   _microtaskLoop (dart:async/schedule_microtask.dart:40:21)
#9346   _startMicrotaskLoop (dart:async/schedule_microtask.dart:49:5)
