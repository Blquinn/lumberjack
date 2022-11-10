import 'package:petitparser/petitparser.dart';
import 'package:json_path/src/grammar/strings.dart';
import 'package:json_path/src/grammar/selector.dart';
import 'package:json_path/src/grammar/number.dart';
import 'package:json_path/src/selector/sequence.dart';
import 'package:json_path/src/selector.dart' as sel;

import 'ast.dart';

//////////////////////////////////////////
/// FilterGrammarDefinition

class FilterGrammarExpbDefinition extends GrammarDefinition<Expression> {
  FilterGrammarExpbDefinition();

  static Parser<String> compareOperator() => (string('<=') |
          string('<') |
          string('>=') |
          string('>') |
          string('!=') |
          string('==') |
          string('='))
      .flatten();

  static Parser<Sequence> jsonPath() =>
      (char(r'$').optional() & selector.star())
          .map((value) => Sequence(value[1].cast<sel.Selector>()));

  final Parser<Expression> _expr = () {
    final builder = ExpressionBuilder<Expression>();

    // Primitive values
    builder.group()
      ..primitive(stringIgnoreCase('null').trim().map((value) => Value(null)))
      ..primitive(stringIgnoreCase('false').trim().map((value) => Value(false)))
      ..primitive(stringIgnoreCase('true').trim().map((value) => Value(true)))
      ..primitive(number.trim().map((value) => Value(value)))
      ..primitive(quotedString.trim().map((value) => Value(value)))
      ..primitive(ref0(jsonPath).trim().map((value) => Selector(value)))
      ..wrapper(
          char('(').trim(), char(')').trim(), (left, value, right) => value);

    // Negation operators
    builder.group()
      ..prefix(stringIgnoreCase('not').trim(),
          (op, a) => Unary('!', a, (ev, expr) => !ev.eval(expr)))
      ..prefix(stringIgnoreCase('!').trim(),
          (op, a) => Unary('!', a, (ev, expr) => !ev.eval(expr)));

    // Comparison operators
    builder.group().left(
        ref0(compareOperator).trim(),
        (left, operator, right) => Binary(operator, left, right,
            (ev, l, r) => ev.evalCompare(l, operator, r)));

    // Boolean operators
    builder.group()
      ..left(
          stringIgnoreCase('and').trim(),
          (left, operator, right) => Binary(
              'and', left, right, (ev, l, r) => ev.eval(l) && ev.eval(r)))
      ..left(
          stringIgnoreCase('or').trim(),
          (left, operator, right) => Binary(
              'or', left, right, (ev, l, r) => ev.eval(l) || ev.eval(r)));

    return builder.build().end();
  }();

  @override
  Parser<Expression> start() => _expr;
}
