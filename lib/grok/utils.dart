// ignore_for_file: prefer_adjacent_string_concatenation, prefer_collection_literals

// Extract Grok patter like %{FOO} to FOO, Also Grok pattern with semantic.
import 'dart:collection';

final RegExp grokPattern = RegExp("%\\{" +
    "(?<name>" +
    "(?<pattern>[A-z0-9]+)" +
    "(?::(?<subname>[A-z0-9_:;,\\-\\/\\s\\.']+))?" +
    ")" +
    "(?:=(?<definition>" +
    "(?:" +
    "(?:[^{}]+|\\.+)+" +
    ")+" +
    ")" +
    ")?" +
    "\\}");

final RegExp namedRegex = RegExp("\\(\\?<([a-zA-Z]\\w*)>");

Set<String> getNameGroups(String regex) {
  Set<String> namedGroups = LinkedHashSet();
  var matches = namedRegex.allMatches(regex);
  for (var match in matches) {
    namedGroups.add(match.group(1)!);
  }
  return namedGroups;
}

Map<String, String?> namedGroups(RegExpMatch match, Set<String> groupNames) {
  Map<String, String?> namedGroups = LinkedHashMap();
  for (var groupName in groupNames) {
    namedGroups[groupName] = match.namedGroup(groupName);
  }
  return namedGroups;
}

int occurencesOfSubstring(String mainString, String search) {
  int i = 0;
  int count = 0;
  while (i != -1) {
    i = mainString.indexOf(search, i);
    if (i != -1) {
      count++;
      i += search.length;
    }
  }
  return count;
}
