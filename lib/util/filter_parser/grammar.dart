// Adapted from https://github.com/isoos/query
// ignore_for_file: non_constant_identifier_names

import 'package:petitparser/petitparser.dart';
import 'package:json_path/src/grammar/strings.dart';
import 'package:json_path/src/grammar/selector.dart';
import 'package:json_path/src/grammar/number.dart';
import 'package:json_path/src/selector/sequence.dart';
import 'package:json_path/src/selector.dart';

import 'ast.dart';

//////////////////////////////////////////
/// FilterGrammarDefinition

class FilterGrammarDefinition extends GrammarDefinition {
  const FilterGrammarDefinition();

  @override
  Parser<Query> start() => ref0(root).end();

  Parser token(Parser parser) => parser.flatten().trim();

  // Handles <exp> AND <exp> sequences (where AND is not optional)
  Parser<Query> root() {
    final g = ref0(or) &
        (ref0(rootSep) & ref0(or))
            .skip(after: whitespace().star())
            .map((list) => list.last)
            .star();

    return g.token().map((list) {
      final children = <Query>[
        list.value.first as Query,
        ...(list.value.last as List).cast<Query>(),
      ];
      if (children.length == 1) return children.single;
      return AndQuery(
          children: children, position: SourcePosition(list.start, list.stop));
    });
  }

  Parser rootSep() =>
      (whitespace().star() & stringIgnoreCase('and') & whitespace().star());

  // Handles <exp> OR <exp> sequences.
  Parser<Query> or() {
    final g = ref0(expression).skip(before: whitespace().star()) &
        (whitespace().plus() &
                stringIgnoreCase('or') &
                whitespace().plus() &
                ref0(root).skip(after: whitespace().star()))
            .map((list) => list.last)
            .star();

    return g.token().map((list) {
      final children = <Query>[
        list.value.first as Query,
        for (final query in (list.value.last as List).cast<Query>())
          // flatten OrQuery children
          if (query is OrQuery)
            for (final child in query.children) child
          else
            query,
      ];
      if (children.length == 1) return children.single;
      return OrQuery(
          children: children, position: SourcePosition(list.start, list.stop));
    });
  }

  Parser expression() => ref0(group) | ref0(comparison);

  Parser<GroupQuery> group() {
    final g = char('(') &
        whitespace().star() &
        ref0(root) &
        whitespace().star() &
        char(')');
    return g.token().map((list) => GroupQuery(
        child: list.value[2] as Query,
        position: SourcePosition(list.start, list.stop)));
  }

  // Can have either a json path, or a value on either side,
  // Separated by a comparison operator.
  Parser<CompareQuery> comparison() {
    final g = ref0(PRIMITIVE_OR_PATH) &
        whitespace().star() &
        ref0(COMP_OPERATOR) &
        whitespace().star() &
        ref0(PRIMITIVE_OR_PATH);

    return g.token().map((list) {
      final position = SourcePosition(list.start, list.stop);

      return CompareQuery(
          left: transformLiteral(position, list.value[0]),
          operator: PrimitiveLiteral(position: position, value: list.value[2]),
          right: transformLiteral(position, list.value[4]),
          position: position);
    });
  }

  Parser<dynamic> PRIMITIVE_OR_PATH() => ref0(PRIMITIVE) | ref0(JSON_PATH_EXPR);

  // Transforms the value from FIELD_OR_PATH to a Literal
  Literal transformLiteral(SourcePosition position, dynamic val) {
    if (val is Selector) {
      return SelectorLiteral(selector: val, position: position);
    } else {
      return PrimitiveLiteral(value: val, position: position);
    }
  }

  Parser<Sequence> JSON_PATH_EXPR() => (char(r'$').optional() & selector.star())
      .map((value) => Sequence(value[1].cast<Selector>()));

  Parser<String> COMP_OPERATOR() => (string('<=') |
          string('<') |
          string('>=') |
          string('>') |
          string('!=') |
          string('==') |
          string('=')
      // string('=~') |
      // stringIgnoreCase('in') |
      )
      .flatten();

  Parser<dynamic> PRIMITIVE() => (string('null').map((_) => null) |
      string('false').map((_) => false) |
      string('true').map((_) => true) |
      number |
      quotedString);
}
