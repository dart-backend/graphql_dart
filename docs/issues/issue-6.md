# Issue 6

I am trying to run mutations like the following, passing an array of objects in my input parameters:

mutation {
    people_insert(input: { people: [{ name: "Bob", age: 25 }]}) { 
        success, 
        message
    } 
}

I have defined my schema inputs and return objects like so:

final personInsertInput = inputObjectType("person_input", inputFields: [
    inputField("name", graphQLString.nonNullable()),
    inputField("age", graphQLInt.nonNullable())
]);

final peopleInsertInput = inputObjectType("people_insert_input", inputFields: [
    inputField("people", listOf(personInsertInput.nonNullable()).nonNullable())
]);

final peopleInsertResult = objectType("people_insert_result", fields: [
    field("success", graphQLBoolean.nonNullable()),
    field("message", graphQLString.nonNullable())
]);

And a mutation object for inserting like this:

var mutationType = objectType("Mutation",
    fields:[      
      field(
        "people_insert",
        peopleInsertResult,
        inputs: [
          GraphQLFieldInput("input", peopleInsertInput)          
        ],
        resolve: (obj, args) async {
          // insert records from args
          return { 'success': true, 'message': 'record(s) inserted.' };
        }
      )]);

When I run the above mutation I get the following response:

{
  "errors": [
    {
      "message": "Type coercion error for value of argument \"input\" of field \"people_insert\". [{people: [{name: Bob, age: 25}]}]",
      "locations": [
        {
          "line": 1,
          "column": 25
        }
      ]
    },
    {
      "message": "type 'List<dynamic>' is not a subtype of type 'List<Map<String, dynamic>>' of 'input'",
      "locations": [
        {
          "line": 1,
          "column": 25
        }
      ]
    }
  ]
}

Have I missed something in my schema definitions or is this not possible yet?

Ideally I'd like to run mutations like this:

mutation($input: people_insert_input!) {
    people_insert(input: $input) { 
        success, 
        message
    } 
}

Passing variables like so:

{
   "input": {   
       "people" : [{
           "name": "Tom",
           "age": 25
       }]
   }
}

But this also results in an error:

{
    "errors": [
        {
            "message": "type 'List<dynamic>' is not a subtype of type 'List<Map<String, dynamic>>' of 'input'"
        }
    ]
}

I've found that if I change my peopleInsertInput to:

final peopleInsertInput = inputObjectType("people_insert_input", inputFields: [
    inputField("people", listOf(personInsertInput.nonNullable()))
]);

Mutations like this work now:

mutation {
    people_insert(input: { people: [{ name: "Bob", age: 25 }]}) { 
        success, 
        message
    } 
}

But if I try to run mutations like this (passing in the $input type):

mutation($input: people_insert_input!) {
    people_insert(input: $input) { 
        success, 
        message
    } 
}

I get a stack overflow exception on the GraphQL.makeLazy() method. Looks to be in an infinite loop in the recursive function.
