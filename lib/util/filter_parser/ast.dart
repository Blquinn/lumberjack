import 'package:json_path/src/selector.dart' as sel;

import 'evaluator.dart';

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
