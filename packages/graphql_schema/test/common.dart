import 'package:graphql_schema2/graphql_schema2.dart';

final GraphQLObjectType pokemonType = objectType(
  'Pokemon',
  fields: [field('species', graphQLString), field('catch_date', graphQLDate)],
);

final GraphQLObjectType trainerType = objectType(
  'Trainer',
  fields: [field('name', graphQLString)],
);

final GraphQLObjectType pokemonRegionType = objectType(
  'PokemonRegion',
  fields: [
    field('trainer', trainerType),
    field('pokemon_species', listOf(pokemonType)),
  ],
);
