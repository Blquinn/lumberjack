import 'dart:convert';
import 'dart:io';

import 'package:lumberjack/util/reverse_line_reader.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

String testFilePath(String fileName) {
  return join(Directory.current.path, 'test/util/test_files', fileName);
}

Future<ReverseLineReader> readerForFile(String fileName) async {
  var file = File(testFilePath(fileName));
  var reader = await ReverseLineReader.create(file);
  return reader;
}

Future<String> getDecodedLine(ReverseLineReader reader) async {
  return const Utf8Decoder().convert(await reader.readLine());
}

void main() {
  group('ReverseLineReader', () {
    test('it handles empty files', () async {
      var reader = await readerForFile("empty_file");
      expect(reader.hasMoreLines(), false);
      expect(await reader.readLine(), []);
    });

    test('it handles file with one line', () async {
      var reader = await readerForFile("one_line_file");
      expect(await getDecodedLine(reader), "ABCD");
      expect(reader.hasMoreLines(), false);
    });

    test('it handles file with multiple lines', () async {
      var reader = await readerForFile("multi_line_file");
      expect(await getDecodedLine(reader), "UVWXYZ");
      expect(await getDecodedLine(reader), "LMNOPQRST");
      expect(await getDecodedLine(reader), "GHIJK");
      expect(await getDecodedLine(reader), "ABCDEF");
      expect(reader.hasMoreLines(), false);
    });

    test('it handles file with blank lines', () async {
      var reader = await readerForFile("blank_line_file");
      expect(await getDecodedLine(reader), "");
      expect(await getDecodedLine(reader), "");
      expect(await getDecodedLine(reader), "XYZ");
      expect(await getDecodedLine(reader), "");
      expect(await getDecodedLine(reader), "ABCD");
      expect(reader.hasMoreLines(), false);
    });

    test('it handles file with escaped newline chars', () async {
      var reader = await readerForFile("newline_char_file");
      expect(await getDecodedLine(reader), "baz");
      expect(await getDecodedLine(reader), "b\\nar");
      expect(await getDecodedLine(reader), "foo");
      expect(reader.hasMoreLines(), false);
    });
  });
}
