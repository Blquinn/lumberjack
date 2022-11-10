import 'package:lumberjack/util/filter_parser/ast.dart';
import 'package:lumberjack/util/filter_parser/evaluator.dart';
import 'package:lumberjack/util/filter_parser/grammar.dart';
import 'package:test/test.dart';

void main() {
  group('Parser', () {
    test('parse primitives', () {
      expect((parser.parse('200').value as Value).value, equals(200));
      expect((parser.parse('20.5').value as Value).value, equals(20.5));
      expect((parser.parse('-200').value as Value).value, equals(-200));
      expect((parser.parse('-20.5').value as Value).value, equals(-20.5));
      expect((parser.parse('true').value as Value).value, equals(true));
      expect((parser.parse('false').value as Value).value, equals(false));
      expect((parser.parse('null').value as Value).value, equals(null));
      expect((parser.parse('"foo"').value as Value).value, equals('foo'));
      expect((parser.parse("'foo'").value as Value).value, equals('foo'));
    });

    test('parse operators', () {
      var p = parser.parse('1 == 1');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());

      p = parser.parse('1 = 1');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = parser.parse('1 != 2');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = parser.parse('1 < 2');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = parser.parse('1 > 2');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isFalse);

      p = parser.parse('1 <= 2');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = parser.parse('1 <= 1');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = parser.parse('1 >= 1');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isTrue);

      p = parser.parse('1 >= 2');
      expect(p.isSuccess, isTrue);
      expect(p.value, isA<Binary>());
      expect(p.value.eval(Evaluator({})), isFalse);
    });

    test('parse selectors', () {
      final res = parser.parse(r'$.foo');
      expect(res.isSuccess, isTrue);
      expect(res.value, isA<Selector>());

      final res2 = parser.parse(r'$["foo"]');
      expect(res2.isSuccess, isTrue);
      expect(res.value, isA<Selector>());

      final res3 = parser.parse(r'.foo');
      expect(res3.isSuccess, isTrue);
      expect(res3.value, isA<Selector>());
    });

    test('can parse a comparison', () {
      final res = parser.parse(r".foo   ==     'bar'");
      expect(res.isSuccess, isTrue);
      expect(res.value, isA<Binary>());
      expect((res.value as Binary).left, isA<Selector>());
      expect((res.value as Binary).name, equals('=='));
      expect((res.value as Binary).right, isA<Value>());

      final res2 = parser.parse(r".foo < 3");
      expect(res2.isSuccess, isTrue);
      expect(res2.value, isA<Binary>());
    });

    test('can parse an and query', () {
      final res = parser.parse(r"  .foo == 'bar' and .bin == 3 ");
      expect(res.isSuccess, isTrue);
      expect(res.value, isA<Binary>());
      expect((res.value as Binary).left, isA<Binary>());
      expect((res.value as Binary).name, equals('and'));
      expect((res.value as Binary).right, isA<Binary>());
    });

    test('can parse an or query', () {
      final res = parser.parse(r"  .foo == 'bar' or .bin == 3 ");
      expect(res.isSuccess, isTrue);
      expect(res.value, isA<Binary>());
      expect((res.value as Binary).left, isA<Binary>());
      expect((res.value as Binary).name, equals('or'));
      expect((res.value as Binary).right, isA<Binary>());
    });

    test('can parse a group', () {
      final res = parser.parse(r"(.foo == 'bar')");
      expect(res.isSuccess, isTrue);
      expect(res.value, isA<Binary>());

      final res2 =
          parser.parse(r"  .foo == 'bar' and (.bin == 3 or .bar < 4)   ");
      expect(res2.isSuccess, isTrue);
      expect(res2.value, isA<Binary>());
      expect((res2.value as Binary).left, isA<Binary>());
      expect((res2.value as Binary).right, isA<Binary>());
    });

    test('can parse a not expression', () {
      final res = parser.parse(r"not (.foo == 'bar')");
      expect(res.isSuccess, isTrue);
      expect(res.value, isA<Unary>());
      expect((res.value as Unary).value, isA<Binary>());

      final res2 = parser.parse(r"!(.foo == 'bar')");
      expect(res2.isSuccess, isTrue);
      expect(res2.value, isA<Unary>());
      expect((res2.value as Unary).value, isA<Binary>());

      final res3 =
          parser.parse(r".foo == 'bar' and not (.bin == 3 or .bar == 4)");
      expect(res3.isSuccess, isTrue);
      expect(res3.value, isA<Binary>());
      expect((res3.value as Binary).left, isA<Binary>());
      expect((res3.value as Binary).right, isA<Unary>());
    });
  });

  group('Filter', () {
    test('filter works on basic equality', () {
      final result = parser.parse('.foo == "bar"');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isTrue);
    });

    test('truthy values dont filter', () {
      final result = parser.parse('true');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isTrue);

      final result2 = parser.parse('.foo');
      final doc2 = {"foo": "bar"};
      expect(result2.isSuccess, isTrue);
      final match2 = result.value.eval(Evaluator(doc2));
      expect(match2, isTrue);
    });

    test('non-truthy values filter', () {
      final result = parser.parse('false');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isFalse);

      final result2 = parser.parse('.bar');
      final doc2 = {"foo": "bar"};
      expect(result2.isSuccess, isTrue);
      final match2 = result.value.eval(Evaluator(doc2));
      expect(match2, isFalse);

      final result3 = parser.parse('.foo');
      final doc3 = {"foo": 0};
      expect(result3.isSuccess, isTrue);
      final match3 = result.value.eval(Evaluator(doc3));
      expect(match3, isFalse);
    });

    test('filter works on nested selectors', () {
      final result = parser.parse('.foo.bar == 3');
      final doc = {
        "foo": {"bar": 3}
      };
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isTrue);
    });

    test('filter fails on non matching doc', () {
      final result = parser.parse('.foo == "blah"');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isFalse);
    });

    test('filter fails gracefully with missing selector', () {
      final result = parser.parse('.flub == "blah"');
      final doc = {"foo": "bar"};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isFalse);
    });

    test('and expression filters', () {
      final result = parser.parse('.foo == "bar" and .bin == 3');
      final doc = {"foo": "bar", "bin": 3};
      expect(result.isSuccess, isTrue);
      final match = result.value.eval(Evaluator(doc));
      expect(match, isTrue);

      final result2 = parser.parse('.foo == "bar" and .bin == 4');
      expect(result2.isSuccess, isTrue);
      final match2 = result2.value.eval(Evaluator(doc));
      expect(match2, isFalse);
    });

    test('or expression filters', () {
      final filter = parser.parse('.foo == "bar" or .bin == 3');
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
      final filter = parser.parse('.foo == 1 or (.bin == 2 and .baz == 3)');
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
      final filter = parser.parse('.foo == 1 and not (.bin == 2 or .baz == 3)');
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
