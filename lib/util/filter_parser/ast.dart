import 'package:json_path/json_path.dart';
import 'package:json_path/src/selector.dart';
// import 'package:json_path/src/grammar/number.dart';
// import 'package:json_path/src/grammar/strings.dart';
// import 'package:json_path/src/grammar/selector.dart';
// import 'package:json_path/src/grammar/number.dart';
// import 'package:json_path/src/selector/field.dart';
// import 'package:json_path/src/selector/sequence.dart';
// import 'package:json_path/src/parser_ext.dart';
// import 'package:json_path/src/algebra.dart';
// import 'package:json_path/src/selector.dart';
import 'package:json_path/src/root_match.dart';

/// A class that describes the position of the source text.
class SourcePosition {
  const SourcePosition(this.start, this.end);

  /// The start position of this query.
  final int start;

  /// The end position of this query, exclusive.
  final int end;

  // The length of this query, in characters.
  int get length => end - start;
}

/// Provides an interface for generic query evaluation.
abstract class QueryEvaluator<R> {
  // R evalText(TextQuery query);
  // R evalValue(ValueQuery query);
  // R evalPhrase(PhraseQuery query);
  // R evalJsonPath(SelectorLiteral path);
  // R evalScope(ScopeQuery query);
  R evalCompare(CompareQuery query);
  // R evalRange(RangeQuery query);
  R evalNot(NotQuery query);
  R evalGroup(GroupQuery query);
  R evalAnd(AndQuery query);
  R evalOr(OrQuery query);
}

// class MatchEvaluator implements QueryEvaluator<bool> {
//   final dynamic json; // The root "json" object.

//   MatchEvaluator(this.json);

// }

/// Base interface for queries.
abstract class Query {
  const Query({
    required this.position,
  });

  /// The position of this query relative to the source.
  final SourcePosition position;

  /// Returns a String-representation of this [Query].
  ///
  /// Implementation should aim to provide a format that can be parsed to the
  /// same form.
  ///
  /// [debug] is used to extend the format with additional characters, making
  /// testing unambiguous.
  @override
  String toString({bool debug = false});

  /// Returns this [Query] cast as [R]
  ///
  /// If the [Query] cannot be cast to [R] it will throw an exception.
  R cast<R extends Query>() => this as R;

  R eval<R>(QueryEvaluator<R> evaluator);
}

abstract class Literal {
  const Literal();
}

/// Value expression.
class PrimitiveLiteral extends Literal {
  final SourcePosition position;
  final dynamic value;

  const PrimitiveLiteral({
    required this.value,
    required this.position,
  });

  // @override
  // R eval<R>(QueryEvaluator<R> evaluator) => evaluator.evalValue(this);

  @override
  String toString({bool debug = false}) => _debug(debug, value);
}

/// Value expression.
class SelectorLiteral extends Literal {
  final Selector selector;
  final SourcePosition position;

  const SelectorLiteral({
    required this.selector,
    required this.position,
  });

  // TODO: If no match, indicate no match somehow.
  dynamic eval(dynamic document) => selector
      .apply(RootMatch(document, MatchingContext({}, Algebra.strict)))
      .first
      .value;

  @override
  String toString({bool debug = false}) => _debug(debug, selector.toString());
}

// /// Describes a [field] [operator] [text] tripled (e.g. year < 2000).
// // ignore: deprecated_member_use_from_same_package
class CompareQuery extends Query {
  final Literal left;
  final PrimitiveLiteral operator;
  final Literal right;

  CompareQuery({
    required this.left,
    required this.operator,
    required this.right,
    required super.position,
  });

  @override
  R eval<R>(QueryEvaluator<R> evaluator) => evaluator.evalCompare(this);

  @override
  String toString({bool debug = false}) =>
      _debug(debug, '$left$operator$right');
}

/// Negates the [child] query. (bool NOT)
class NotQuery extends Query {
  final Query child;
  const NotQuery({
    required this.child,
    required super.position,
  });

  @override
  R eval<R>(QueryEvaluator<R> evaluator) => evaluator.evalNot(this);

  @override
  String toString({bool debug = false}) => '-${child.toString(debug: debug)}';
}

/// Groups the [child] query to override implicit precedence.
class GroupQuery extends Query {
  final Query child;
  const GroupQuery({
    required this.child,
    required super.position,
  });

  @override
  R eval<R>(QueryEvaluator<R> evaluator) => evaluator.evalGroup(this);

  @override
  String toString({bool debug = false}) => '(${child.toString(debug: debug)})';
}

/// Bool AND composition of [children] queries.
class AndQuery extends Query {
  final List<Query> children;

  const AndQuery({
    required this.children,
    required super.position,
  });

  @override
  R eval<R>(QueryEvaluator<R> evaluator) => evaluator.evalAnd(this);

  @override
  String toString({bool debug = false}) =>
      '(${children.map((n) => n.toString(debug: debug)).join(' ')})';
}

/// Bool OR composition of [children] queries.
class OrQuery extends Query {
  final List<Query> children;

  const OrQuery({
    required this.children,
    required super.position,
  });

  @override
  R eval<R>(QueryEvaluator<R> evaluator) => evaluator.evalOr(this);

  @override
  String toString({bool debug = false}) =>
      '(${children.map((n) => n.toString(debug: debug)).join(' OR ')})';
}

String _debug(bool debug, String expr) => debug ? '<$expr>' : expr;
