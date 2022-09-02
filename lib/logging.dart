import 'dart:convert';

import 'package:logger/logger.dart';

final levelNames = {
  Level.verbose: 'VERBOSE',
  Level.debug: 'DEBUG',
  Level.info: 'INFO',
  Level.warning: 'WARN',
  Level.error: 'ERROR',
  Level.wtf: 'WTF',
};

class JsonPrinter extends LogPrinter {
  JsonPrinter();

  @override
  List<String> log(LogEvent event) {
    return [
      jsonEncode({
        "level": levelNames[event.level],
        "timestamp": DateTime.now().toUtc().toIso8601String(),
        "message": event.message,
      })
    ];
  }
}
