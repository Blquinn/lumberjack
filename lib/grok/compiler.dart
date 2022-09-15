import 'dart:convert';

import 'package:flutter/services.dart';

import 'grok.dart';
import 'utils.dart' as utils;

final RegExp grokLineRex = RegExp("^(\\w+)\\s+(.+)\$");

final RegExp grokPattern = RegExp("%\\{" +
    "(?<name>" +
    "(?<pattern>[A-Za-z0-9]+)" +
    "(?::(?<subname>[A-z0-9_:;,\\-\\/\\s\\.']+))?" +
    ")" +
    "(?:=(?<definition>" +
    "(?:" +
    "(?:[^{}]+|\\.+)+" +
    ")+" +
    ")" +
    ")?" +
    "\\}");

class GrokCompiler {
  final Map<String, String> grokPatternDefinitions = {};

  void register(String name, String pattern) {
    if (name.isNotEmpty && pattern.isNotEmpty) {
      grokPatternDefinitions[name] = pattern;
    }
  }

  Future registerDefaultPatterns() async {
    await registerPatternFromAssets("lib/grok/assets/patterns");
  }

  Future registerPatternFromAssets(String path) async {
    var splitter = const LineSplitter();
    var lines = splitter.convert(await rootBundle.loadString(path));
    for (var line in lines) {
      var match = grokLineRex.firstMatch(line);
      if (match == null) continue;

      register(match.group(1)!, match.group(2)!);
    }
  }

  Grok compile(String pattern, [bool namedOnly = true]) {
    if (pattern.isEmpty) {
      throw 'Empty pattern';
    }

    var namedRegex = pattern;
    const int maxIters = 1000;
    var patternDefinitions = Map.from(grokPatternDefinitions);
    Map<String, String> namedRegexCollection = {};
    int nameIndex = 0;

    for (int i = 0; i < maxIters; i++) {
      var namedGroups = utils.getNameGroups(grokPattern.pattern);
      var match = grokPattern.firstMatch(namedRegex);

      if (match == null) break;

      var group = utils.namedGroups(match, namedGroups);

      var definition = match.namedGroup("definition");
      if (definition != null) {
        patternDefinitions[match.namedGroup("pattern")!] = definition;
        group["name"] = "${group["name"]!}=$definition";
      }

      var count =
          utils.occurencesOfSubstring(namedRegex, "%{${group["name"]!}}");
      for (var ci = 0; ci < count; ci++) {
        var defOfPattern = patternDefinitions[group["pattern"]];
        if (defOfPattern == null) {
          throw 'No definition found for pattern ${group["pattern"]}';
        }

        String replacement;
        if (namedOnly && group["subname"] == null) {
          replacement = "(?:$defOfPattern)";
        } else {
          replacement = "(?<name$nameIndex>$defOfPattern)";
        }

        namedRegexCollection['name$nameIndex'] =
            group["subname"] ?? group["name"]!;

        namedRegex =
            namedRegex.replaceFirst("%{${group["name"]}}", replacement);

        nameIndex++;
      }

      if (namedRegex.isEmpty) {
        throw 'Pattern not found.';
      }
    }

    if (maxIters < 0) {
      throw 'Passed recusion limit.';
    }

    return Grok(
        pattern, namedRegex, namedRegexCollection, grokPatternDefinitions);
  }
}

Future<GrokCompiler> defaultCompiler() async {
  var c = GrokCompiler();
  await c.registerDefaultPatterns();
  return c;
}
