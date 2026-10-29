# AI Context: graphql_dart

Context for AI coding assistants working in this repository. Read this before making changes.

## What this is

A Dart implementation of the [GraphQL specification (June 2018)](https://graphql.github.io/graphql-spec/June2018/), maintained as a monorepo under the `dart-backend` organization (part of the Angel3 framework ecosystem). It provides a parser, a type system, a framework-agnostic execution engine, a code generator, a DataLoader port, and an Angel3 HTTP/WebSocket plugin.

- Repo: https://github.com/dart-backend/graphql_dart
- Dart SDK: `>=3.13.0 <4.0.0` (CI pins `3.13.0`)
- Tooling: Dart pub workspaces (root `pubspec.yaml`) + Melos (`melos.yaml`)

## Packages

Directory names differ from published package names; most published names carry a `2` suffix because they are forks of the original Angel `graphql_*` packages.

| Directory | Package | Version | Role |
|---|---|---|---|
| `packages/graphql_parser` | `graphql_parser2` | 8.0.0 | Lexer + recursive-descent parser; GraphQL AST (`*Context` classes) |
| `packages/graphql_schema` | `graphql_schema2` | 8.0.0 | Type system: scalars, object/input/enum/union types, schema, validation, annotations |
| `packages/graphql_server` | `graphql_server2` | 9.0.0 | Execution engine (`GraphQL` class), introspection, Apollo `subscriptions-transport-ws` |
| `packages/graphql_generator` | `graphql_generator2` | 8.0.0 | `build_runner` builder: Dart classes → `GraphQLObjectType`s |
| `packages/graphql_data_loader` | `graphql_data_loader2` | 8.0.0 | Port of JS `graphql/dataloader` (batching + caching); no runtime deps |
| `packages/angel_graphql` | `angel3_graphql` | 10.0.0 | Angel3 integration: HTTP handler, WebSocket handler, GraphiQL, service resolvers |

### Dependency graph

```
graphql_parser2   graphql_schema2        graphql_data_loader2 (standalone)
        \            /     \
       graphql_server2    graphql_generator2 (+ analyzer, source_gen, angel3_serialize_generator)
              |
        angel3_graphql (+ angel3_framework, angel3_websocket, ...)
```

`graphql_schema2` and `graphql_parser2` are the foundation; a change to their public API ripples to everything above. `graphql_server2` must stay framework-agnostic: it depends on no Angel package, only `graphql_schema2`, `graphql_parser2`, `collection`, `recase` and `stream_channel`.

## Key code locations

- **Executor**: `packages/graphql_server/lib/graphql_server2.dart` (~1100 lines, the largest file). Class `GraphQL` with `parseAndExecute`, `executeRequest`, `executeField`, `completeValue`, `createSourceEventStream` (subscriptions). Follows the spec's algorithm names closely; keep that correspondence when editing.
- **Introspection**: `packages/graphql_server/lib/introspection.dart` (`__Schema`, `__Type`, etc.).
- **Apollo WS transport**: `packages/graphql_server/lib/subscriptions_transport_ws.dart` and `lib/src/apollo/`.
- **Parser**: `packages/graphql_parser/lib/src/language/` (`lexer.dart`, `parser.dart`, `ast/*.dart`, one file per AST node).
- **Type system**: `packages/graphql_schema/lib/src/`. `schema.dart` is the `part`-root (contains `GraphQLSchema`, `GraphQLException`, annotations `GraphQLDocumentation`/`GraphQLClass`/`graphQLClass`); other files are `part of 'schema.dart'`. `gen.dart` holds the DSL helpers (`objectType`, `inputObjectType`, `field`, `listOf`, ...).
- **Generator**: `packages/graphql_generator/lib/src/graphql_generator.dart`; builder config in `packages/graphql_generator/build.yaml` (builder `graphql`, factory `graphQLBuilder`, output `.graphql_generator2.g.part`, requires `angel3_serialize.g.part`, combined via `source_gen|combining_builder`).
- **Angel3 plugin**: `packages/angel_graphql/lib/src/` with `graphQLHttp(...)`, `graphQLWS(...)`, `graphiQL(...)`, and `resolveViaService{Index,FindOne,Read,Create,...}` in `resolvers.dart`. `GraphQLUploadType` lives in `lib/angel3_graphql.dart`.

## Typical usage (for orientation)

```dart
var schema = graphQLSchema(
  queryType: objectType('Query', fields: [
    field('todos', listOf(todoType), resolve: (_, args) => ...),
  ]),
);
app.all('/graphql', graphQLHttp(GraphQL(schema)));  // angel3_graphql
app.get('/graphiql', graphiQL());
```

Generator usage: annotate a class with `@graphQLClass` (optionally `@GraphQLDocumentation(...)` on fields), add `part 'x.g.dart';`, run `dart run build_runner build`, then use the generated `<camelName>GraphQLType`.

## Development Workflow

- **Master Branch**: Stable release branch (`graphql_parser2`, `graphql_schema2` and `graphql_generator2` 8.x, `graphql_server2` 9.x, `graphql_data_loader2` 8.x, `angel3_graphql` 10.x). All PRs target `master`.
- **Feature Branches**: Work is done on `feature/<name>` branches (e.g. `feature/dart3.13` for the SDK 3.13 upgrade) and bug fixes on `bugfix/<name>`. Contributors fork the repo, then branch from `master`.
- **Setup**: Install melos (`dart pub global activate melos`), then run `dart pub get` at the root. That resolves the whole workspace into the root `pubspec.lock`, which is tracked in git. Upgrade all packages with `melos exec "dart pub upgrade"`.
- **Code generation**: After changing `graphql_generator2`, regenerate its example with `dart run build_runner build --delete-conflicting-outputs` in `packages/graphql_generator`. The output, `example/main.g.dart`, is committed and must not be edited by hand.
- **Checks**: Before finishing work, run in each package you touched, from that package's directory:

  ```bash
  dart format --output=none --set-exit-if-changed .
  dart analyze
  dart test
  ```

  Across all packages: `melos exec -- "dart analyze ."` and `melos exec -- "dart test"`. Run examples from their package directory too, as some read files relative to it (e.g. `angel_graphql/example/subscription.dart` reads `posts.json`).
- **CI**: GitHub Actions (`.github/workflows/dart.yml`, SDK pinned to `3.13.0`) runs format, analyze and test for `graphql_schema`, `graphql_parser` and `graphql_server` only. `graphql_generator`, `graphql_data_loader` and `angel_graphql` are not checked by CI, so run their checks locally. CI fails on any `dart format` diff.
- **Lints**: Each package uses `package:lints/recommended.yaml`; some disable `non_constant_identifier_names` / `constant_identifier_names`.
- **Tests**: `graphql_parser` has the most tests (one file per construct, shared helpers in `test/common.dart`), `graphql_schema` has a few, and the other packages have about one `all_test.dart` each. When fixing a reported bug, add a regression test named after the issue (see `graphql_parser/test/issue23_test.dart`).
- **Releases**: Bump `version` in the package's `pubspec.yaml`, update sibling packages' constraints to match on a major bump, and add a `## <version>` entry to its `CHANGELOG.md` (see **Changelog**). SDK upgrades bump the min SDK in every package and the root `pubspec.yaml` together.
- **Changelog**: Every user-facing change gets an entry in the affected package's `CHANGELOG.md`, written as plain-English statements about the package (not commit messages). Group a release's entries under `### Breaking changes in X.Y.Z` (each entry prefixed `**Breaking:**`), `### New in X.Y.Z` and `### Fixes in X.Y.Z`, in that order, omitting empty sections. Prefix each fix with a bold area label, e.g. `* **Services:** An invalid id is a 400`. See `packages/graphql_schema/CHANGELOG.md` (8.0.0) for the reference style; entries before it are flat bullet lists. Commit messages use [Conventional Commits](https://www.conventionalcommits.org/) (`type(scope): description`, `!` for breaking changes).


## Conventions

- Each package uses `resolution: workspace`; don't add per-package lockfiles or `dependency_overrides` for sibling packages, since the workspace already links them.
- Inter-package constraints use caret versions (`graphql_schema2: ^8.0.0`). When bumping a package's major version, update dependents' constraints and the root workspace together.
- Version scheme: `graphql_parser2`, `graphql_schema2` and `graphql_generator2` are on 8.x, `graphql_server2` on 9.x and `graphql_data_loader2` on 8.x; `angel3_graphql` tracks Angel3 on 10.x.
- Null safety throughout; prefer explicit types on public APIs.
- Public API is exported from each package's top-level `lib/<package_name>.dart`; implementation lives in `lib/src/`.

## Gotchas

- Directory name ≠ package name (`packages/angel_graphql` → `angel3_graphql`, `packages/graphql_server` → `graphql_server2`). Imports use the package name.
- `graphql_schema2` uses `part`/`part of`. New type files must be added as `part` directives in `schema.dart`, not imported.
- `graphql_generator2` depends on `analyzer` (^14) and `source_gen` (^4); analyzer major bumps usually require API migration in `graphql_generator.dart`.
- No package uses `dart:mirrors` (the `graphql_server2` mirrors helpers were removed in 9.0.0). Don't reintroduce it: types come from `graphql_generator2` or the `graphql_schema2` DSL, keeping everything AOT-compatible.
- `.iml` files at root and in packages are IntelliJ project files. Leave them alone unless asked.
- `packages/angel_graphql/posts.json` is test/example data, not config.
