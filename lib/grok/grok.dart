// Parses grok pattern from grok pattern line.
import 'package:lumberjack/grok/utils.dart' as utils;
import 'match.dart';

final RegExp grokPatternRex = RegExp("\\%\\{(.+):(\\w+)\\}");

///
/// {@code Grok} parse arbitrary text and structure it.
/// <br>
/// {@code Grok} is simple API that allows you to easily parse logs
/// and other files (single line). With {@code Grok},
/// you can turn unstructured log and event data into structured data.
class Grok {
  ///
  /// Named regex of the originalGrokPattern.
  ///
  final String namedRegex;

  ///
  ///  Map of the named regex of the originalGrokPattern
  ///  with id = namedregexid and value = namedregex.
  ///
  final Map<String, String> namedRegexCollection;

  ///
  /// Original {@code Grok} pattern (expl: %{IP}).
  ///
  final String originalGrokPattern;

  ///
  /// Pattern of the namedRegex.
  ///
  late final RegExp compiledNamedRegex;

  ///
  /// {@code Grok} patterns definition.
  ///
  final Map<String, String> grokPatternDefinition;

  // public
  late final Set<String> namedGroups;

  Grok(
    this.originalGrokPattern,
    this.namedRegex,
    this.namedRegexCollection,
    this.grokPatternDefinition,
    // ZoneId defaultTimeZone) {
  ) {
    compiledNamedRegex = RegExp(namedRegex);
    namedGroups = utils.getNameGroups(namedRegex);
  }

  ///
  /// Match the given <tt>log</tt> with the named regex.
  /// And return the json representation of the matched element
  ///
  /// @param log : log to match
  /// @return map containing matches
  ///
  Map<String, dynamic> capture(String log) {
    return match(log)?.capture() ?? {};
  }

  ///
  /// Match the given <tt>text</tt> with the named regex
  /// {@code Grok} will extract data from the string and get an extence of {@link Match}.
  ///
  /// @param text : Single line of log
  /// @return Grok Match
  ///
  Match? match(String text) {
    var match = compiledNamedRegex.firstMatch(text);
    if (match == null) return null;
    return Match(text, this, match);
  }
}
