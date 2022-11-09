import 'package:json_path/src/selector/sequence.dart';
import 'package:lumberjack/util/filter_parser/ast.dart';
import 'package:lumberjack/util/filter_parser/grammar.dart';
import 'package:test/test.dart';

void main() {
  final grammarDef = FilterGrammarDefinition();
  final grammar = grammarDef.build();

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
      assert(res.value.children[0] is CompareQuery);
      assert(res.value.children[1] is CompareQuery);
    });

    test('can parse an or query', () {
      final res = grammar.parse(r"   .foo == 'bar' or .bin == 3  ");
      expect(res.isSuccess, isTrue);
      assert(res.value is OrQuery);
      assert(res.value.children[0] is CompareQuery);
      assert(res.value.children[1] is CompareQuery);
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
  });
}
