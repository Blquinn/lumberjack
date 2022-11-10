import 'package:lumberjack/logging.dart';
import 'package:lumberjack/util/filter_parser/ast.dart';
import 'package:lumberjack/util/filter_parser/evaluator.dart';

abstract class LogFilter {
  bool match(Map<String, dynamic> row);
}

class ExpressionFilter implements LogFilter {
  final Expression expression;

  ExpressionFilter(this.expression);

  @override
  bool match(Map<String, dynamic> row) {
    try {
      return expression.eval(Evaluator(row));
    } catch (e) {
      log.w('Failed to evaluate log line $e');
      return false;
    }
  }
}

class TextFilter implements LogFilter {
  final String _filter;

  TextFilter(String filter) : _filter = filter.toLowerCase().trim();

  @override
  bool match(Map<String, dynamic> row) {
    for (final e in row.entries) {
      if (e.value.toString().toLowerCase().contains(_filter)) {
        return true;
      }
    }
    return false;
  }
}
