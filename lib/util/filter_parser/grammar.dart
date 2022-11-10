import 'package:json_path/json_path.dart';
import 'package:petitparser/petitparser.dart';
import 'package:json_path/src/grammar/strings.dart';
import 'package:json_path/src/grammar/selector.dart';
import 'package:json_path/src/grammar/number.dart';
import 'package:json_path/src/selector/sequence.dart';
import 'package:json_path/src/selector.dart' as sel;

import 'ast.dart';

//////////////////////////////////////////
/// FilterGrammarDefinition

Parser<Sequence> jsonPath() => (char(r'$').optional() & selector.star())
    .map((value) => Sequence(value[1].cast<sel.Selector>()));

final Parser<Expression> parser = () {
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
  builder.group()
    ..left(string('==').trim(), compareExpr((alg) => alg.eq))
    ..left(string('!=').trim(), compareExpr((alg) => alg.ne))
    ..left(string('<=').trim(), compareExpr((alg) => alg.le))
    ..left(string('>=').trim(), compareExpr((alg) => alg.ge))
    ..left(char('<').trim(), compareExpr((alg) => alg.lt))
    ..left(char('>').trim(), compareExpr((alg) => alg.gt))
    ..left(char('=').trim(), compareExpr((alg) => alg.eq));

  // Boolean operators
  builder.group()
    ..left(
        stringIgnoreCase('and').trim(),
        (left, operator, right) =>
            Binary('and', left, right, (ev, l, r) => ev.eval(l) && ev.eval(r)))
    ..left(
        stringIgnoreCase('or').trim(),
        (left, operator, right) =>
            Binary('or', left, right, (ev, l, r) => ev.eval(l) || ev.eval(r)));

  return builder.build().end();
}();

// Creates a binary expression that compares two other expressions.
Expression Function(Expression left, String operator, Expression right)
    compareExpr(bool Function(dynamic, dynamic) Function(Algebra alg) opFunc) {
  return (l, o, r) =>
      Binary(o, l, r, (ev, l, r) => ev.evalCompare(l, opFunc(ev.algebra), r));
}
