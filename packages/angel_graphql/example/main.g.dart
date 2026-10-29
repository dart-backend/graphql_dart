// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Todo extends TodoEntity {
  Todo({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.text,
    this.completed,
    this.completionStatus,
  });

  /// A unique identifier corresponding to this item.
  @override
  String? id;

  /// The time at which this item was created.
  @override
  DateTime? createdAt;

  /// The last time at which this item was updated.
  @override
  DateTime? updatedAt;

  @override
  String? text;

  @override
  bool? completed;

  @override
  CompletionStatus? completionStatus;

  Todo copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? text,
    bool? completed,
    CompletionStatus? completionStatus,
  }) {
    return Todo(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      completionStatus: completionStatus ?? this.completionStatus,
    );
  }

  @override
  bool operator ==(other) {
    return other is TodoEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.text == text &&
        other.completed == completed &&
        other.completionStatus == completionStatus;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      createdAt,
      updatedAt,
      text,
      completed,
      completionStatus,
    ]);
  }

  @override
  String toString() {
    return 'Todo(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, text=$text, completed=$completed, completionStatus=$completionStatus)';
  }

  Map<String, dynamic> toJson() {
    return TodoSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const TodoSerializer todoSerializer = TodoSerializer();

class TodoEncoder extends Converter<Todo, Map> {
  const TodoEncoder();

  @override
  Map convert(Todo model) => TodoSerializer.toMap(model);
}

class TodoDecoder extends Converter<Map, Todo> {
  const TodoDecoder();

  @override
  Todo convert(Map map) => TodoSerializer.fromMap(map);
}

class TodoSerializer extends Codec<Todo, Map> {
  const TodoSerializer();

  @override
  TodoEncoder get encoder => const TodoEncoder();

  @override
  TodoDecoder get decoder => const TodoDecoder();

  static Todo fromMap(Map map) {
    return Todo(
      id: map['id'] as String?,
      createdAt: map['created_at'] != null
          ? (map['created_at'] is DateTime
                ? (map['created_at'] as DateTime)
                : DateTime.parse(map['created_at'].toString()))
          : null,
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is DateTime
                ? (map['updated_at'] as DateTime)
                : DateTime.parse(map['updated_at'].toString()))
          : null,
      text: map['text'] as String?,
      completed: map['completed'] as bool?,
      completionStatus: map['completion_status'] as CompletionStatus?,
    );
  }

  static Map<String, dynamic> toMap(TodoEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'text': model.text,
      'completed': model.completed,
      'completion_status': model.completionStatus,
    };
  }
}

abstract class TodoFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    text,
    completed,
    completionStatus,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String text = 'text';

  static const String completed = 'completed';

  static const String completionStatus = 'completion_status';
}

// **************************************************************************
// _GraphQLGenerator
// **************************************************************************

/// Auto-generated from [Todo].
final GraphQLObjectType todoGraphQLType = objectType(
  'Todo',
  isInterface: false,
  description: 'A task that might not be completed yet. **Yay! Markdown!**',
  interfaces: [],
  fields: [
    field<dynamic, dynamic>(
      'id',
      graphQLId,
      resolve: (obj, _) => (obj as TodoEntity).id,
    ),
    field<dynamic, dynamic>(
      'created_at',
      graphQLDate,
      resolve: (obj, _) => (obj as TodoEntity).createdAt,
    ),
    field<dynamic, dynamic>(
      'updated_at',
      graphQLDate,
      resolve: (obj, _) => (obj as TodoEntity).updatedAt,
    ),
    field<dynamic, dynamic>(
      'text',
      graphQLString,
      resolve: (obj, _) => (obj as TodoEntity).text,
    ),
    field<dynamic, dynamic>(
      'completed',
      graphQLBoolean,
      deprecationReason: 'Use `completion_status` instead.',
      resolve: (obj, _) => (obj as TodoEntity).completed,
    ),
    field<dynamic, dynamic>(
      'completion_status',
      completionStatusGraphQLType,
      resolve: (obj, _) => (obj as TodoEntity).completionStatus?.name,
    ),
  ],
);

/// Auto-generated from [CompletionStatus].
final GraphQLEnumType<String> completionStatusGraphQLType = enumTypeFromStrings(
  'CompletionStatus',
  const ['COMPLETE', 'INCOMPLETE'],
  description: 'The completion status of a to-do item.',
);
