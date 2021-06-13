import 'package:graphql_parser2/graphql_parser2.dart';

Parser parse(String text) => Parser(scan(text));
