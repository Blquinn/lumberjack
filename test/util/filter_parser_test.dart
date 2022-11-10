import 'dart:math';

import 'package:lumberjack/util/filter_parser/ast.dart';
import 'package:lumberjack/util/filter_parser/evaluator.dart';
import 'package:lumberjack/util/filter_parser/grammar.dart';
import 'package:test/test.dart';

void main() {
  final grammar = parser;

  group('Parser', () {
    test('parse primitives', () {
      expect((grammar.parse('200').value as Value).value, equals(200));
      expect((grammar.parse('20.5').value as Value).value, equals(20.5));
      expect((grammar.parse('-200').value as Value).value, equals(-200));
      expect((grammar.parse('-20.5').value as Value).value, equals(-20.5));
      expect((grammar.parse('true').value as Value).value, equals(true));
      expect((grammar.parse('false').value as Value).value, equals(false));
      expect((grammar.parse('null').value as Value).value, equals(null));
      expect((grammar.parse('"foo"').value as Value).value, equals('foo'));
      expect((grammar.parse("'foo'").value as Value).value, equals('foo'));
    });

    test('parse operators', () {
      var p = grammar.parse('1 == 1');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());

      p = grammar.parse('1 = 1');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = grammar.parse('1 != 2');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = grammar.parse('1 < 2');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = grammar.parse('1 > 2');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isFalse);

      p = grammar.parse('1 <= 2');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = grammar.parse('1 <= 1');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = grammar.parse('1 >= 1');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = grammar.parse('1 >= 2');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isFalse);
    });

    test('parse selectors', () {
      final res = grammar.parse(r'$.foo');
      expect(res.isSuccess, isTrue);
      assert(res.value is Selector);

      final res2 = grammar.parse(r'$["foo"]');
      expect(res2.isSuccess, isTrue);
      assert(res.value is Selector);

      final res3 = grammar.parse(r'.foo');
      expect(res3.isSuccess, isTrue);
      assert(res3.value is Selector);
    });

    test('can parse a comparison', () {
      final res = grammar.parse(r".foo   ==     'bar'");
      expect(res.isSuccess, isTrue);
      assert(res.value is Binary);
      assert((res.value as Binary).left is Selector);
      assert((res.value as Binary).name == '==');
      assert((res.value as Binary).right is Value);

      final res2 = grammar.parse(r".foo < 3");
      expect(res2.isSuccess, isTrue);
      assert(res2.value is Binary);
    });

    test('can parse an and query', () {
      final res = grammar.parse(r"  .foo == 'bar' and .bin == 3 ");
      expect(res.isSuccess, isTrue);
      assert(res.value is Binary);
      assert((res.value as Binary).left is Binary);
      assert((res.value as Binary).name == 'and');
      assert((res.value as Binary).right is Binary);
    });

    test('can parse an or query', () {
      final res = grammar.parse(r"  .foo == 'bar' or .bin == 3 ");
      expect(res.isSuccess, isTrue);
      assert(res.value is Binary);
      assert((res.value as Binary).left is Binary);
      assert((res.value as Binary).name == 'or');
      assert((res.value as Binary).right is Binary);
    });

    test('can parse a group', () {
      final res = grammar.parse(r"(.foo == 'bar')");
      expect(res.isSuccess, isTrue);
      assert(res.value is Binary);

      final res2 =
          grammar.parse(r"  .foo == 'bar' and (.bin == 3 or .bar < 4)   ");
      expect(res2.isSuccess, isTrue);
      assert(res2.value is Binary);
      assert((res2.value as Binary).left is Binary);
      assert((res2.value as Binary).right is Binary);
    });

    test('can parse a not expression', () {
      final res = grammar.parse(r"not (.foo == 'bar')");
      expect(res.isSuccess, isTrue);
      assert(res.value is Unary);
      assert((res.value as Unary).value is Binary);

      final res2 = grammar.parse(r"!(.foo == 'bar')");
      expect(res2.isSuccess, isTrue);
      assert(res2.value is Unary);
      assert((res2.value as Unary).value is Binary);

      final res3 =
          grammar.parse(r".foo == 'bar' and not (.bin == 3 or .bar == 4)");
      expect(res3.isSuccess, isTrue);
      assert(res3.value is Binary);
      assert((res3.value as Binary).left is Binary);
      assert((res3.value as Binary).right is Unary);
    });
  });

  group('Filter', () {
    test('filter works on basic equality', () {
      final result = grammar.parse('.foo == "bar"');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isTrue);
    });

    test('truthy values dont filter', () {
      final result = grammar.parse('true');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isTrue);

      final result2 = grammar.parse('.foo');
      final doc2 = {"foo": "bar"};
      expect(result2.isSuccess, isTrue);
      final match2 = result.value.eval(Evaluator(doc2));
      expect(match2, isTrue);
    });

    test('non-truthy values filter', () {
      final result = grammar.parse('false');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isFalse);

      final result2 = grammar.parse('.bar');
      final doc2 = {"foo": "bar"};
      expect(result2.isSuccess, isTrue);
      final match2 = result.value.eval(Evaluator(doc2));
      expect(match2, isFalse);

      final result3 = grammar.parse('.foo');
      final doc3 = {"foo": 0};
      expect(result3.isSuccess, isTrue);
      final match3 = result.value.eval(Evaluator(doc3));
      expect(match3, isFalse);
    });

    test('filter works on nested selectors', () {
      final result = grammar.parse('.foo.bar == 3');
      final doc = {
        "foo": {"bar": 3}
      };
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isTrue);
    });

    test('filter fails on non matching doc', () {
      final result = grammar.parse('.foo == "blah"');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isFalse);
    });

    test('filter fails gracefully with missing selector', () {
      final result = grammar.parse('.flub == "blah"');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isFalse);
    });

    test('and expression filters', () {
      final result = grammar.parse('.foo == "bar" and .bin == 3');
      final doc = {"foo": "bar", "bin": 3};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isTrue);

      final result2 = grammar.parse('.foo == "bar" and .bin == 4');
      expect(result2.isSuccess, isTrue);
      final match2 = result2.value.eval(Evaluator(doc));
      expect(match2, isFalse);
    });

    test('or expression filters', () {
      final filter = grammar.parse('.foo == "bar" or .bin == 3');
      expect(filter.isSuccess, isTrue);

      final doc1 = {"foo": "bar", "bin": 4};
      final match = filter.value.eval(Evaluator(doc1));
      expect(match, isTrue);

      final doc2 = {"foo": "quux", "bin": 3};
      final match2 = filter.value.eval(Evaluator(doc2));
      expect(match2, isTrue);

      final doc3 = {"foo": "quux", "bin": 4};
      final match3 = filter.value.eval(Evaluator(doc3));
      expect(match3, isFalse);
    });

    test('group expression filters', () {
      final filter = grammar.parse('.foo == 1 or (.bin == 2 and .baz == 3)');
      expect(filter.isSuccess, isTrue);

      final doc1 = {"foo": 1, "bin": 4};
      final match = filter.value.eval(Evaluator(doc1));
      expect(match, isTrue);

      final doc2 = {"foo": 2, "bin": 2, "baz": 3};
      final match2 = filter.value.eval(Evaluator(doc2));
      expect(match2, isTrue);

      final doc3 = {"foo": "quux", "bin": 2};
      final match3 = filter.value.eval(Evaluator(doc3));
      expect(match3, isFalse);

      final doc4 = {"foo": "quux", "baz": 3};
      final match4 = filter.value.eval(Evaluator(doc4));
      expect(match4, isFalse);
    });

    test('not expression filters', () {
      final filter =
          grammar.parse('.foo == 1 and not (.bin == 2 or .baz == 3)');
      expect(filter.isSuccess, isTrue);

      final doc1 = {"foo": 1, "bin": 4};
      final match = filter.value.eval(Evaluator(doc1));
      expect(match, isTrue);

      final doc2 = {"foo": 1, "bin": 2};
      final match2 = filter.value.eval(Evaluator(doc2));
      expect(match2, isFalse);
    });
  });
}
