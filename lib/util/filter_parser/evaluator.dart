import 'package:json_path/src/root_match.dart';
import 'package:json_path/src/matching_context.dart';
import 'package:json_path/src/algebra.dart';

import 'ast.dart';

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

  bool evalCompare(Expression left, bool Function(dynamic, dynamic) operator,
      Expression right) {
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

    return operator(leftVal, rightVal);
  }
}

bool doesStringContain(l, r) {
  if (!(l is String && r is String)) {
    return false;
  }

  return l.contains(r);
}

bool isStringIn(l, r) {
  if (!(l is String && r is String)) {
    return false;
  }

  return r.contains(l);
}

bool doesRegexMatch(l, r) {
  if (!(l is RegExp || r is RegExp)) {
    return false;
  }

  if (!(l is String || r is String)) {
    return false;
  }

  RegExp re;
  String str;

  if (l is RegExp) {
    re = l;
    str = r;
  } else {
    str = l;
    re = r;
  }

  return re.hasMatch(str);
}
