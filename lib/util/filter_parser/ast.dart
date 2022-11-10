import 'package:json_path/src/selector.dart' as sel;
import 'package:json_path/src/root_match.dart';
import 'package:json_path/src/matching_context.dart';
import 'package:json_path/src/algebra.dart';

class Evaluator {
  final dynamic document; // The root "json" object.
  final Algebra algebra;

  Evaluator(this.document, {this.algebra = Algebra.relaxed});

  bool eval(Expression expr) {
    switch (expr.runtimeType) {
      case Value:
        return evalValue(expr as Value);
      case Selector:
        return evalSelector(expr as Selector);
      case Binary:
        final bin = expr as Binary;
        return bin.function(this, bin.left, bin.right);
      case Unary:
        final un = expr as Unary;
        return un.function(this, un.value);
      default:
        throw UnsupportedError('Received expression of unhandled type $expr');
    }
  }

  bool evalValue(Value value) {
    return algebra.isTruthy(value.value);
  }

  bool evalSelector(Selector selector) {
    final matches = selector.selector
        .apply(RootMatch(document, MatchingContext({}, algebra)))
        .toList();

    if (matches.length != 1) {
      return false;
    }

    return algebra.isTruthy(matches[0].value);
  }

  List<dynamic> selectorToMatchValues(Selector selector) {
    return selector.selector
        .apply(RootMatch(document, MatchingContext({}, algebra)))
        .map((e) => e.value)
        .toList();
  }

  bool evalCompare(Expression left, String operator, Expression right) {
    dynamic leftVal;
    dynamic rightVal;

    if (left is Selector) {
      final matches = selectorToMatchValues(left);
      if (matches.length != 1) {
        return false;
      }

      leftVal = matches[0];
    } else if (left is Value) {
      leftVal = left.value;
    }

    if (right is Selector) {
      final matches = selectorToMatchValues(right);
      if (matches.length != 1) {
        return false;
      }

      rightVal = matches[0];
    } else if (right is Value) {
      rightVal = right.value;
    }

    switch (operator) {
      case "==":
      case "=":
        return algebra.eq(leftVal, rightVal);
      case "!=":
        return algebra.ne(leftVal, rightVal);
      case "<":
        return algebra.lt(leftVal, rightVal);
      case ">":
        return algebra.gt(leftVal, rightVal);
      case "<=":
        return algebra.le(leftVal, rightVal);
      case ">=":
        return algebra.ge(leftVal, rightVal);
      default:
        throw UnsupportedError('The operator $operator is not supported.');
    }
  }
}

abstract class Expression {
  bool eval(Evaluator evaluator);
}

class Value extends Expression {
  Value(this.value);

  final dynamic value;

  @override
  bool eval(Evaluator evaluator) => evaluator.evalValue(this);
}

class Selector extends Expression {
  Selector(this.selector);

  final sel.Selector selector;

  @override
  bool eval(Evaluator evaluator) => evaluator.evalSelector(this);
}

class Unary extends Expression {
  Unary(this.name, this.value, this.function);

  final String name;
  final Expression value;
  final bool Function(Evaluator evaluator, Expression value) function;

  @override
  bool eval(Evaluator evaluator) => function(evaluator, value);
}

class Binary extends Expression {
  Binary(this.name, this.left, this.right, this.function);

  final String name;
  final Expression left;
  final Expression right;
  final bool Function(Evaluator evaluator, Expression left, Expression right)
      function;

  @override
  bool eval(Evaluator evaluator) => function(evaluator, left, right);
}
