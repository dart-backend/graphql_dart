# Issue 13

When a @graphQLClass annotated class does not have a default constructor the generator throws an exception.

Example class:

@graphQLClass
class ItemGQO {
  String publicId = "";
  String name = "";

  //ItemPrintingGroupGQO();

  ItemPrintingGroupGQO.fromModel(Item model)
      : publicId = model.publicId,
        name = model.name;
}

The generated error message:

[SEVERE] graphql_generator2:graphql on lib/src/network/model/item_gqo.dart:

Null check operator used on a null value

Expected behavior:

    As the generated code does not depend on the constructor the code can be generated
    A helpful error message which tells the user to add the constructor
