// ignore_for_file: prefer_collection_literals

import 'dart:collection';

import 'grok.dart';
import 'utils.dart' as utils;

///
/// {@code Match} is a representation in {@code Grok} world of your log.
///
/// @since 0.0.1
///
class Match {
  final String subject;
  final Grok grok;
  final RegExpMatch match;
  bool keepEmptyCaptures = true;
  LinkedHashMap<String, dynamic> _capture = LinkedHashMap();

  Match(this.subject, this.grok, this.match);

  ///
  /// Ignore empty captures.
  ///
  void setKeepEmptyCaptures(bool ignore) {
    if (_capture.isNotEmpty) {
      _capture = LinkedHashMap();
    }
    keepEmptyCaptures = ignore;
  }

  ///
  /// Private implementation of captureFlattened and capture.
  /// @param flattened will it flatten values.
  /// @return the matched elements.
  /// @throws GrokException if a keys has multiple non-null values, but only if flattened is set to true.
  ///
  Map<String, dynamic> capture([bool flattened = false]) {
    if (_capture.isNotEmpty) {
      return _capture;
    }

    _capture = LinkedHashMap();

    // _capture.put("LINE", this.line);
    // _capture.put("LENGTH", this.line.length() +"");

    var mappedw = utils.namedGroups(match, grok.namedGroups);

    mappedw.forEach((key, valueString) {
      var id = grok.namedRegexCollection[key];
      if (id != null && id.isNotEmpty) {
        key = id;
      }

      if ("UNWANTED" == key) {
        return;
      }

      var value = valueString;
      if (valueString != null && valueString.isNotEmpty) {
        value = _cleanString(valueString);
      } else if (!keepEmptyCaptures) {
        return;
      }

      if (_capture.containsKey(key)) {
        var currentValue = _capture[key];

        if (flattened) {
          // if (currentValue == null && value != null) {
          if (currentValue != null) {
            throw "Key $key has multiple values, which is not allowed in flattened mode.";
          }

          _capture[key] = value;
        } else {
          if (currentValue is List) {
            List<dynamic> cvl = currentValue;
            cvl.add(value);
          } else {
            List<dynamic> list = [];
            list.add(currentValue);
            list.add(value);
            _capture[key] = list;
          }
        }
      } else {
        _capture[key] = value;
      }
    });

    return _capture;
  }

  ///
  /// remove from the string the quote and double quote.
  ///
  /// @param value string to pure: "my/text"
  /// @return unquoted string: my/text
  ///
  String _cleanString(String value) {
    if (value.isEmpty) {
      return value;
    }

    var firstChar = value[0];
    var lastChar = value[value.length - 1];

    if (firstChar == lastChar && (firstChar == '"' || firstChar == '\'')) {
      if (value.length <= 2) {
        return "";
      } else {
        int found = 0;
        for (int i = 1; i < value.length - 1; i++) {
          if (value[i] == firstChar) {
            found++;
          }
        }
        if (found == 0) {
          return value.substring(1, value.length - 1);
        }
      }
    }

    return value;
  }
}
