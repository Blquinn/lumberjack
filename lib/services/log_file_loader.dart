import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../logging.dart';
import '../util/reverse_line_reader.dart';

class LinesResult {
  final Set<String> columns;
  final List<DataGridRow> rows;
  LinesResult(this.columns, this.rows);
}

class LogFileLoader {
  final String filePath;
  late File _file;
  final Function onNewLinesAvailable;

  StreamSubscription? _fileWatchSubscription;
  int _lastReadPosBackwards = 0;
  int _lastReadPosForwards = 0;

  LogFileLoader._(this.filePath, this.onNewLinesAvailable) {
    _file = File(filePath);
  }

  static Future<LogFileLoader> create(
      String filePath, Function onNewLinesAvailable) async {
    var loader = LogFileLoader._(filePath, onNewLinesAvailable);
    await loader.init();
    return loader;
  }

  Future init() async {
    var fileLen = await _file.length();
    _lastReadPosBackwards = fileLen;
    _lastReadPosForwards = fileLen;

    _fileWatchSubscription =
        _file.watch(events: FileSystemEvent.modify).listen((e) {
      log.d("File changed, loading more rows.");
      onNewLinesAvailable();
    });
  }

  Future<LinesResult> readMore(int maxLines, [bool backwards = true]) async {
    Set<String> newCols = {};

    var start = Stopwatch();
    start.start();

    List<DataGridRow> rows = [];

    var linesRead = 0;

    readLine(List<int> lineBytes) {
      var line = const Utf8Decoder().convert(lineBytes);
      if (line.isEmpty) return;

      Map<String, dynamic> rowMap = jsonDecode(line);
      for (var k in rowMap.keys) {
        newCols.add(k);
      }

      var cells = rowMap.entries
          .map((entry) =>
              DataGridCell(columnName: entry.key, value: entry.value))
          .toList();

      rows.add(DataGridRow(cells: cells));

      linesRead++;
    }

    if (backwards) {
      var reader = await ReverseLineReader.create(_file, _lastReadPosBackwards);
      while (reader.hasMoreLines() && linesRead < maxLines) {
        readLine(await reader.readLine());
      }
      _lastReadPosBackwards = reader.position;
    } else {
      var fileSize = await _file.length();
      var stream = _file.openRead(_lastReadPosForwards, fileSize);
      var bytes =
          await stream.reduce((previous, element) => previous + element);
      readLine(bytes);
      _lastReadPosForwards += bytes.length;
    }

    log.d("Read ${rows.length} rows in ${start.elapsed}.");

    return LinesResult(newCols, rows);
  }

  Future close() async {
    await _fileWatchSubscription?.cancel();
  }
}
