import 'package:angel3_framework/angel3_framework.dart';
import 'package:graphql_schema2/graphql_schema2.dart';

export 'src/graphiql.dart';
export 'src/graphql_http.dart';
export 'src/graphql_ws.dart';
export 'src/resolvers.dart';

/// The canonical [GraphQLUploadType] instance.
final GraphQLUploadType graphQLUpload = GraphQLUploadType();

/// A [GraphQLScalarType] that is used to read uploaded files from
/// `multipart/form-data` requests.
class GraphQLUploadType extends GraphQLScalarType<UploadedFile, UploadedFile> {
  @override
  String get name => 'Upload';

  @override
  String get description =>
      'Represents a file that has been uploaded to the server.';

  @override
  GraphQLType<UploadedFile, UploadedFile> coerceToInputObject() => this;

  @override
  UploadedFile deserialize(UploadedFile serialized) => serialized;

  @override
  UploadedFile serialize(UploadedFile value) => value;

  /// Accepts an [UploadedFile], as a multipart request's variables hold.
  @override
  ValidationResult<UploadedFile> validate(String key, input) {
    if (input is UploadedFile) return ValidationResult.ok(input);
    return ValidationResult.failure([
      'Expected "$key" to be an uploaded file.',
    ]);
  }
}
