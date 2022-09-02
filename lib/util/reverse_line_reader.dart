import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void reverseList<T>(List<T> list) {
  for (var i = 0; i < list.length / 2; i++) {
    var temp = list[i];
    list[i] = list[list.length - 1 - i];
    list[list.length - 1 - i] = temp;
  }
}

// TODO: This is slow because dart:io sucks. Find a way to optimize.
class ReverseLineReader {
  static const int chunkSize = 2 << 10;

  final File file;
  int position;

  static final Uint8List _newlineChars = const Utf8Encoder().convert("\r\n");
  static int get crByte => _newlineChars[0];
  static int get lfByte => _newlineChars[1];

  ReverseLineReader._({required this.file, required this.position});

  static Future<ReverseLineReader> create(File file, [int? position]) async {
    var size = await file.length();
    var reader =
        ReverseLineReader._(file: file, position: position ?? max(size, 0));
    await reader.init(size);
    return reader;
  }

  Future init(int size) async {
    var endSize = min(size, 2);
    var bytes = await _readNBytes(endSize);
    position -= endSize;
    if (endSize == 1 && bytes[0] == lfByte) {
      position += 1;
    } else if (endSize == 2) {
      if (bytes[0] != crByte) position += 1;
      if (bytes[1] != lfByte) position += 1;
    }
  }

  bool hasMoreLines() {
    return position > 0;
  }

  Future<List<int>> readLine() async {
    List<int> lineChars = [];

    Outer:
    while (true) {
      if (position < 1) {
        if (lineChars.isNotEmpty) break;
        return lineChars;
      }

      var bts = await _readNBytes(chunkSize);

      for (var i = bts.length - 1; i >= 0; i--) {
        var char = bts[i];
        position--;

        if (char == lfByte) {
          if (i > 1 && bts[i - 1] == crByte) position--;
          break Outer;
        }

        lineChars.add(char);
      }
    }

    reverseList(lineChars);
    return lineChars;
  }

  Future<List<int>> _readNBytes(int size) async {
    var start = max(position - size, 0);
    var stream = file.openRead(start, position);
    var bytes = await stream.reduce((previous, element) => previous + element);
    return bytes;
  }
}
