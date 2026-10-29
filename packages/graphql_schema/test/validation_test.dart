import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:test/test.dart';

void main() {
  var typeType = enumTypeFromStrings('Type', ['FIRE', 'WATER', 'GRASS']);

  var pokemonType = objectType(
    'Pokémon',
    fields: [
      field('name', graphQLString.nonNullable()),
      field('type', typeType),
    ],
  );

  var isValidPokemon = predicate(
    (dynamic x) =>
        pokemonType.validate('@root', x as Map<String, dynamic>).successful,
    'is a valid Pokémon',
  );

  test('object accepts valid input', () {
    expect({'name': 'Charmander', 'type': 'FIRE'}, isValidPokemon);
  });

  test('mismatched scalar type', () {
    expect({'name': 24}, isNot(isValidPokemon));
  });

  test('empty passed for non-nullable', () {
    expect(<String, dynamic>{}, isNot(isValidPokemon));
  });

  test('null passed for non-nullable', () {
    var result = pokemonType.validate('@root', {'name': null});
    expect(result.successful, false);
    expect(result.errors, ['Field "name", of type String!, cannot be null.']);
  });

  test('null passed for nullable field', () {
    expect({'name': 'Ditto', 'type': null}, isValidPokemon);
  });

  test('rejects extraneous fields', () {
    expect({'name': 'Vulpix', 'foo': 'bar'}, isNot(isValidPokemon));
  });

  test('enum accepts valid value', () {
    expect(typeType.validate('@root', 'FIRE').successful, true);
  });

  test('enum rejects invalid value', () {
    expect(typeType.validate('@root', 'POISON').successful, false);
  });

  group('union type', () {
    var digimonType = objectType(
      'Digimon',
      fields: [field('size', graphQLFloat.nonNullable())],
    );

    var u = GraphQLUnionType('Monster', [pokemonType, digimonType]);

    test('any of its types returns valid', () {
      expect(u.validate('@root', {'size': 32.0}).successful, true);
      expect(
        u.validate('@root', {'name': 'Charmander', 'type': 'FIRE'}).successful,
        true,
      );
    });
  });

  group('input object', () {
    var type = inputObjectType(
      'Foo',
      inputFields: [
        inputField('bar', graphQLString.nonNullable()),
        inputField('baz', graphQLFloat.nonNullable()),
      ],
    );

    test('accept valid input', () {
      expect(type.validate('@root', {'bar': 'a', 'baz': 2.0}).value, {
        'bar': 'a',
        'baz': 2.0,
      });
    });

    test('error on missing non-null fields', () {
      expect(type.validate('@root', {'bar': 'a'}).successful, false);
    });

    test('error on unrecognized fields', () {
      expect(
        type.validate('@root', {
          'bar': 'a',
          'baz': 2.0,
          'franken': 'stein',
        }).successful,
        false,
      );
    });
  });

  group('wrongly typed input fails instead of throwing', () {
    void expectFailure(GraphQLType type, Object? input) =>
        expect(type.validate('x', input).successful, false);

    test('list', () => expectFailure(listOf(graphQLId), 'abc'));
    test('object', () => expectFailure(pokemonType, 5));
    test('input object', () {
      expectFailure(
        GraphQLInputObjectType(
          'F',
          inputFields: [GraphQLInputObjectField('a', graphQLString)],
        ),
        5,
      );
    });
    test('union', () => expectFailure(GraphQLUnionType('U', [pokemonType]), 5));
    test('string bounds', () => expectFailure(graphQLStringMin(1), 42));
    test('number bounds', () => expectFailure(graphQLIntMin(1), 'a'));
    test('enum', () => expectFailure(typeType, 3));
    test('non-null', () => expectFailure(graphQLString.nonNullable(), null));
  });

  group('number', () {
    test('Float accepts and coerces an Int', () {
      var result = graphQLFloat.validate('price', 3);
      expect(result.successful, true);
      expect(result.value, 3.0);
      expect(graphQLFloat.deserialize(3), 3.0);
    });

    test('Int rejects a Float', () {
      expect(graphQLInt.validate('n', 3.5).successful, false);
    });

    test('Int cannot deserialize a Float', () {
      expect(() => graphQLInt.deserialize(3.5), throwsArgumentError);
    });

    test('bounds reject null and check values', () {
      expect(graphQLInt.validate('x', null).successful, false);
      expect(graphQLIntMin(1).validate('x', null).successful, false);
      expect(graphQLIntMin(1).validate('x', 0).successful, false);
      expect(graphQLIntMax(1).validate('x', 2).successful, false);
      expect(graphQLIntRange(1, 3).validate('x', 2).successful, true);
    });
  });

  group('enum', () {
    var color = enumType('Color', {'RED': 1, 'BLUE': 2});
    var paint = objectType('Paint', fields: [field('color', color)]);

    test('object accepts a value name', () {
      expect(paint.validate('x', {'color': 'RED'}).successful, true);
    });

    test('object accepts a Dart value, as in resolver output', () {
      var result = paint.validate('x', {'color': 1});
      expect(result.successful, true);
      expect(result.value, {'color': 'RED'});
    });

    test('enum rejects a Dart value as input', () {
      expect(color.validate('x', 1).successful, false);
      expect(
        GraphQLInputObjectType(
          'PaintInput',
          inputFields: [GraphQLInputObjectField('color', color)],
        ).validate('x', {'color': 1}).successful,
        false,
      );
    });

    test('Dart values are converted, preferring values over names', () {
      var e = enumType('E', {'A': 'B', 'B': 'C'});
      expect(e.convert('B'), 'A');
      expect(e.validate('x', 'B').value, 'B');
      expect(
        objectType(
          'O',
          fields: [field('e', e)],
        ).validate('x', {'e': 'B'}).value,
        {'e': 'A'},
      );
    });

    test('object accepts a list of Dart values', () {
      var palette = objectType(
        'Palette',
        fields: [field('colors', listOf(color))],
      );
      expect(
        palette.validate('x', {
          'colors': [1, 2],
        }).value,
        {
          'colors': ['RED', 'BLUE'],
        },
      );
    });

    test('object rejects an unknown value', () {
      expect(paint.validate('x', {'color': 'GREEN'}).successful, false);
    });

    test('non-null enum accepts a Dart value', () {
      var type = objectType(
        'Paint',
        fields: [field('color', color.nonNullable())],
      );
      expect(type.validate('x', {'color': 2}).successful, true);
    });
  });

  group('null list items', () {
    test('are accepted when the list can hold them', () {
      var type = listOf<dynamic, dynamic>(graphQLString);
      var result = type.validate('x', ['a', null]);
      expect(result.successful, true);
      expect(result.value, ['a', null]);
      expect(type.deserialize(['a', null]), ['a', null]);
    });

    test('are rejected for a list of non-nullable Dart values', () {
      var result = listOf(graphQLString).validate('x', ['a', null]);
      expect(result.successful, false);
      expect(result.errors, [
        'Expected "x" at index 1 to be a non-null value.',
      ]);
    });

    test('are rejected for a non-null item type', () {
      expect(
        listOf<dynamic, dynamic>(graphQLString.nonNullable())
            .validate('x', ['a', null])
            .successful,
        false,
      );
    });
  });

  test('null field values serialize and deserialize', () {
    var input = GraphQLInputObjectType(
      'I',
      inputFields: [
        GraphQLInputObjectField('name', graphQLString),
        GraphQLInputObjectField('when', graphQLDate),
      ],
    );
    var value = {'name': 'x', 'when': null};
    expect(input.validate('x', value).successful, true);
    expect(input.deserialize(value), value);
    expect(input.serialize(value), value);

    var output = objectType('O', fields: [field('name', graphQLString)]);
    expect(output.deserialize({'name': null}), {'name': null});
    expect(output.serialize({'name': null}), {'name': null});
  });

  test('nested validated values are kept', () {
    var inner = GraphQLInputObjectType(
      'Inner',
      inputFields: [GraphQLInputObjectField('n', graphQLFloat)],
    );
    var outer = GraphQLInputObjectType(
      'Outer',
      inputFields: [GraphQLInputObjectField('items', listOf(inner))],
    );

    var result = outer.validate('x', {
      'items': [
        <dynamic, dynamic>{'n': 1},
      ],
    });
    expect(result.successful, true);
    var items = result.value!['items'] as List;
    expect(items.single, isA<Map<String, dynamic>>());
    expect((items.single as Map)['n'], isA<double>());
  });

  test('object accepts a DateTime, as in resolver output', () {
    var date = DateTime.utc(2020);
    var event = objectType('Event', fields: [field('at', graphQLDate)]);
    expect(event.validate('x', {'at': date}).value, {
      'at': date.toIso8601String(),
    });
    expect(graphQLDate.validate('d', date).successful, false);
  });

  test('field arguments can have their own types', () {
    var f = field(
      'user',
      objectType('User'),
      inputs: [GraphQLFieldInput('id', graphQLInt)],
    );
    expect(f.inputs.single.type, graphQLInt);
  });

  test('union cannot be coerced to an input type', () {
    var union = GraphQLUnionType('U', [pokemonType]);
    expect(union.coerceToInputObject, throwsUnsupportedError);
  });

  group('toInputObject', () {
    var union = GraphQLUnionType('U', [pokemonType]);

    test('leaves out nullable union and interface fields', () {
      var shape = objectType(
        'Shape',
        isInterface: true,
        fields: [field('name', graphQLString)],
      );
      var holder = objectType(
        'Holder',
        fields: [
          field('name', graphQLString),
          field('u', union),
          field('us', listOf(union.nonNullable())),
          field('shape', shape),
        ],
      );
      var input = holder.toInputObject('HolderInput');
      expect(input.inputFields.map((f) => f.name), ['name']);
    });

    test('rejects a non-null union field', () {
      var holder = objectType(
        'Holder',
        fields: [
          field('name', graphQLString),
          field('us', listOf(union).nonNullable()),
        ],
      );
      expect(() => holder.toInputObject('HolderInput'), throwsUnsupportedError);
    });

    test('rejects an object with no input fields left', () {
      var holder = objectType('Holder', fields: [field('u', union)]);
      expect(holder.coerceToInputObject, throwsUnsupportedError);
    });

    test('handles a type that refers to itself', () {
      var todo = objectType('Todo', fields: [field('text', graphQLString)]);
      todo.fields.add(field('parent', todo));
      var input = todo.toInputObject('TodoInput');
      expect(input.inputFields.last.type, same(input));
    });

    test('handles types that refer to each other', () {
      var a = objectType('A', fields: [field('n', graphQLInt)]);
      var b = objectType('B', fields: [field('a', a)]);
      a.fields.add(field('b', b));
      var aInput = a.coerceToInputObject() as GraphQLInputObjectType;
      var bInput = aInput.inputFields.last.type as GraphQLInputObjectType;
      expect(bInput.name, 'BInput');
      expect(bInput.inputFields.single.type, same(aInput));
    });
  });

  group('lists with null items', () {
    var color = enumType('Color', {'RED': 1, 'BLUE': 2});

    test('convert keeps null items the list can hold', () {
      var palette = objectType(
        'Palette',
        fields: [field('colors', listOf<dynamic, dynamic>(color))],
      );
      expect(
        palette.validate('x', {
          'colors': [1, null],
        }).value,
        {
          'colors': ['RED', null],
        },
      );
    });

    test('serialize keeps null items the list can hold', () {
      expect(listOf<dynamic, dynamic>(color).serialize([1, null]), [
        'RED',
        null,
      ]);
    });

    test(
      'only the null item is reported for a list of non-nullable values',
      () {
        var palette = objectType(
          'Palette',
          fields: [field('colors', listOf(color))],
        );
        expect(
          palette.validate('x', {
            'colors': [1, null],
          }).errors,
          ['x: Expected "colors" at index 1 to be a non-null value.'],
        );
      },
    );

    test('serialize rejects a null item for a non-null item type', () {
      expect(
        () =>
            listOf<dynamic, dynamic>(color.nonNullable()).serialize([1, null]),
        throwsArgumentError,
      );
    });

    test('serialize rejects a null item the list cannot hold', () {
      expect(
        () => GraphQLListType<int?, String>(
          GraphQLEnumType<int?>('C', [GraphQLEnumValue('RED', 1)]),
        ).serialize([1, null]),
        throwsArgumentError,
      );
    });
  });

  group('Int given for Float', () {
    test('deserializes for Float!', () {
      var type = graphQLFloat.nonNullable();
      var value = type.validate('x', 1).value;
      expect(type.deserialize(value!), 1.0);
    });

    test('deserializes for [Float]', () {
      var type = listOf(graphQLFloat);
      var value = type.validate('x', [1, 2]).value;
      expect(type.deserialize(value!), [1.0, 2.0]);
    });

    test('deserializes for an input field of type Float!', () {
      var type = GraphQLInputObjectType(
        'I',
        inputFields: [GraphQLInputObjectField('f', graphQLFloat.nonNullable())],
      );
      var value = type.validate('x', {'f': 1}).value;
      expect(type.deserialize(value!), {'f': 1.0});
    });
  });
}
