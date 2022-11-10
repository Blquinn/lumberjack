import 'package:json_path/src/selector/sequence.dart';
import 'package:lumberjack/util/filter_parser/ast.dart';
import 'package:lumberjack/util/filter_parser/grammar.dart';
import 'package:test/test.dart';

void main() {
  const grammarDef = FilterGrammarDefinition();
  final grammar = grammarDef.build<Query>();

  group('Parser', () {
    test('parse primitives', () {
      final prim = grammarDef.PRIMITIVE();
      expect(prim.parse('200').value, equals(200));
      expect(prim.parse('20.5').value, equals(20.5));
      expect(prim.parse('-200').value, equals(-200));
      expect(prim.parse('-20.5').value, equals(-20.5));
      expect(prim.parse('true').value, equals(true));
      expect(prim.parse('false').value, equals(false));
      expect(prim.parse('null').value, equals(null));
      expect(prim.parse('"foo"').value, equals('foo'));
      expect(prim.parse("'foo'").value, equals('foo'));
    });

    test('parse operators', () {
      final res = grammarDef.COMP_OPERATOR().parse('==');
      expect(res.isSuccess, isTrue);
      expect(res.value, equals('=='));
    });

    test('parse selectors', () {
      final res = grammarDef.JSON_PATH_EXPR().parse(r'$.foo');
      expect(res.isSuccess, isTrue);

      final res2 = grammarDef.JSON_PATH_EXPR().parse(r'$["foo"]');
      expect(res2.isSuccess, isTrue);
      // expect(res.value, equals(Sequence([Field('foo')])));
    });

    test('parse field/path/literal', () {
      final pop = grammarDef.build(start: grammarDef.PRIMITIVE_OR_PATH);
      // Field
      final res = pop.parse(r'.foo');
      expect(res.isSuccess, isTrue);
      assert(res.value is Sequence);

      // Path
      final res2 = pop.parse(r'$["foo"]["bar"]');
      expect(res2.isSuccess, isTrue);
      assert(res2.value is Sequence);

      // Primitive
      final res3 = pop.parse(r'200');
      expect(res3.isSuccess, isTrue);
      expect(res3.value, equals(200));
    });

    test('can parse a comparison', () {
      final comp = grammarDef.build(start: grammarDef.comparison);

      final res = comp.parse(r".foo   ==     'bar'");
      expect(res.isSuccess, isTrue);
      assert(res.value is CompareQuery);
      assert(res.value.left is SelectorLiteral);
      assert(res.value.operator is PrimitiveLiteral);
      assert(res.value.right is PrimitiveLiteral);

      final res2 = comp.parse(r".foo < 3");
      expect(res2.isSuccess, isTrue);
      assert(res2.value is CompareQuery);
    });

    test('can parse an and query', () {
      final res = grammar.parse(r"  .foo == 'bar' and .bin == 3 ");
      expect(res.isSuccess, isTrue);
      assert(res.value is AndQuery);
      assert((res.value as AndQuery).children[0] is CompareQuery);
      assert((res.value as AndQuery).children[1] is CompareQuery);
    });

    test('can parse an or query', () {
      final res = grammar.parse(r"   .foo == 'bar' or .bin == 3  ");
      expect(res.isSuccess, isTrue);
      assert(res.value is OrQuery);
      assert((res.value as OrQuery).children[0] is CompareQuery);
      assert((res.value as OrQuery).children[1] is CompareQuery);
    });

    test('can parse a group', () {
      final res = grammar.parse(r"(.foo == 'bar')");
      expect(res.isSuccess, isTrue);
      assert(res.value is GroupQuery);

      final res2 =
          grammar.parse(r"  .foo == 'bar' and (.bin == 3 or .bar < 4)   ");
      expect(res2.isSuccess, isTrue);
      assert(res2.value is AndQuery);
      assert((res2.value as AndQuery).children[0] is CompareQuery);
      assert((res2.value as AndQuery).children[1] is GroupQuery);
    });

    test('can parse a not expression', () {
      final res = grammar.parse(r"not .foo == 'bar'");
      expect(res.isSuccess, isTrue);
      assert(res.value is NotQuery);
      assert((res.value as NotQuery).child is CompareQuery);

      final res2 = grammar.parse(r"!(.foo == 'bar')");
      expect(res2.isSuccess, isTrue);
      assert(res2.value is NotQuery);
      assert((res2.value as NotQuery).child is GroupQuery);

      final res3 =
          grammar.parse(r".foo == 'bar' and not (.bin == 3 or .bar == 4)");
      expect(res3.isSuccess, isTrue);
      assert(res3.value is AndQuery);
      assert((res3.value as AndQuery).children[0] is CompareQuery);
      assert((res3.value as AndQuery).children[1] is NotQuery);
    });
  });

  group('Filter', () {
    test('filter works on basic equality', () {
      final result = grammar.parse('.foo == "bar"');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(MatchEvaluator(doc));
      expect(match, isTrue);
    });

    test('filter works on nested selectors', () {
      final result = grammar.parse('.foo.bar == 3');
      final doc = {
        "foo": {"bar": 3}
      };
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(MatchEvaluator(doc));
      expect(match, isTrue);
    });

    test('filter fails on non matching doc', () {
      final result = grammar.parse('.foo == "blah"');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(MatchEvaluator(doc));
      expect(match, isFalse);
    });

    test('filter fails gracefully with missing selector', () {
      final result = grammar.parse('.flub == "blah"');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(MatchEvaluator(doc));
      expect(match, isFalse);
    });

    test('and expression filters', () {
      final result = grammar.parse('.foo == "bar" and .bin == 3');
      final doc = {"foo": "bar", "bin": 3};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(MatchEvaluator(doc));
      expect(match, isTrue);

      final result2 = grammar.parse('.foo == "bar" and .bin == 4');
      expect(result2.isSuccess, isTrue);
      final match2 = result2.value.eval(MatchEvaluator(doc));
      expect(match2, isFalse);
    });

    test('or expression filters', () {
      final filter = grammar.parse('.foo == "bar" or .bin == 3');
      expect(filter.isSuccess, isTrue);

      final doc1 = {"foo": "bar", "bin": 4};
      final match = filter.value.eval(MatchEvaluator(doc1));
      expect(match, isTrue);

      final doc2 = {"foo": "quux", "bin": 3};
      final match2 = filter.value.eval(MatchEvaluator(doc2));
      expect(match2, isTrue);

      final doc3 = {"foo": "quux", "bin": 4};
      final match3 = filter.value.eval(MatchEvaluator(doc3));
      expect(match3, isFalse);
    });

    test('group expression filters', () {
      final filter = grammar.parse('.foo == 1 or (.bin == 2 and .baz == 3)');
      expect(filter.isSuccess, isTrue);

      final doc1 = {"foo": 1, "bin": 4};
      final match = filter.value.eval(MatchEvaluator(doc1));
      expect(match, isTrue);

      final doc2 = {"foo": 2, "bin": 2, "baz": 3};
      final match2 = filter.value.eval(MatchEvaluator(doc2));
      expect(match2, isTrue);

      final doc3 = {"foo": "quux", "bin": 2};
      final match3 = filter.value.eval(MatchEvaluator(doc3));
      expect(match3, isFalse);

      final doc4 = {"foo": "quux", "baz": 3};
      final match4 = filter.value.eval(MatchEvaluator(doc4));
      expect(match4, isFalse);
    });

    test('not expression filters', () {
      final filter =
          grammar.parse('.foo == 1 and not (.bin == 2 or .baz == 3)');
      expect(filter.isSuccess, isTrue);

      final doc1 = {"foo": 1, "bin": 4};
      final match = filter.value.eval(MatchEvaluator(doc1));
      expect(match, isTrue);

      final doc2 = {"foo": 1, "bin": 2};
      final match2 = filter.value.eval(MatchEvaluator(doc2));
      expect(match2, isFalse);
    });
  });
}
