import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../logging.dart';

class LogTable extends StatelessWidget {
  const LogTable({
    Key? key,
    required this.dataSource,
  }) : super(key: key);

  final LogFileDataSource dataSource;

  @override
  Widget build(BuildContext context) {
    return SfDataGrid(
        source: dataSource,
        columnWidthMode: ColumnWidthMode.fill,
        loadMoreViewBuilder: ((context, loadMoreRows) {
          Future<String> loadRows() async {
            await loadMoreRows();
            return Future<String>.value('Completed');
          }

          return FutureBuilder<String>(
              initialData: 'loading',
              future: loadRows(),
              builder: (context, snapShot) {
                if (snapShot.data == 'loading') {
                  return Container(
                      height: 60.0,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          border: BorderDirectional(
                              top: BorderSide(
                                  width: 1.0,
                                  color: Color.fromRGBO(0, 0, 0, 0.26)))),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation(Colors.deepPurple)));
                } else {
                  return SizedBox.fromSize(size: Size.zero);
                }
              });
        }),
        columns: dataSource.columns
            .map(
              (c) => GridColumn(
                  columnName: 'id',
                  label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: Text(c))),
            )
            .toList());
  }
}

/// An object to set the employee collection data source to the datagrid. This
/// is used to map the employee data to the datagrid widget.
class LogFileDataSource extends DataGridSource {
  /// Creates the employee data source class with required details.
  String filePath;
  late File file;
  // Cacnel this when file changes.
  StreamSubscription? fileWatchSubscription;
  int lastReadPosBackwards = 0;
  int lastReadPosForwards = 0;

  LogFileDataSource({required this.filePath}) {
    file = File(filePath);
    init();
  }

  void setFilePath(String path) {}

  Future init() async {
    var fileLen = await file.length();
    lastReadPosBackwards = fileLen;
    lastReadPosForwards = fileLen;
    await readMore();

    fileWatchSubscription =
        file.watch(events: FileSystemEvent.modify).listen((e) {
      log.d("File changed, loading more rows.");
      EasyDebounce.debounce('read-forward-debounce',
          const Duration(milliseconds: 100), () => readMore(false));
    });
  }

  Future readMore([bool backwards = true]) async {
    Set<String> newCols = {};

    var start = Stopwatch();
    start.start();

    List<DataGridRow> rows = [];

    const linesToRead = 100;
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
      var reader =
          ReverseLineReader(file: file, position: lastReadPosBackwards);
      while (reader.hasMoreLines() && linesRead < linesToRead) {
        readLine(await reader.readLine());
      }
      lastReadPosBackwards = reader.position;
    } else {
      var fileSize = await file.length();
      var stream = file.openRead(lastReadPosForwards, fileSize);
      var bytes =
          await stream.reduce((previous, element) => previous + element);
      readLine(bytes);
      lastReadPosForwards += bytes.length;
    }

    if (backwards) {
      _rows.addAll(rows);
    } else {
      for (var row in rows) {
        _rows.insert(0, row);
      }
    }

    log.d("Added ${rows.length} rows in ${start.elapsed}.");

    _columns.addAll(newCols.difference(_columns.toSet()));

    notifyListeners();
  }

  @override
  Future<void> handleLoadMoreRows() async {
    EasyDebounce.debounce('read-backward-debounce',
        const Duration(milliseconds: 100), () => readMore());
  }

  final List<DataGridRow> _rows = [];
  final List<String> _columns = [];

  List<String> get columns => _columns;

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    var cells = row.getCells();

    return DataGridRowAdapter(
        cells: columns.map<Widget>((col) {
      String columnText = "";
      for (var cell in cells) {
        if (cell.columnName == col) {
          columnText = cell.value.toString();
          break;
        }
      }

      return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(2.0),
          child: Text(columnText));
    }).toList());
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

  ReverseLineReader({required this.file, required this.position});

  Future init() async {
    var size = await file.length();
    var endSize = min(size, 2);
    var bytes = await _readNBytes(endSize);
    if (endSize == 1 && bytes[0] == lfByte) {
      position += 1;
    } else if (endSize == 2) {
      if (bytes[0] != crByte) position += 1;
      if (bytes[1] != lfByte) position += 1;
    }
  }

  static void reverseList<T>(List<T> list) {
    for (var i = 0; i < list.length / 2; i++) {
      var temp = list[i];
      list[i] = list[list.length - 1 - i];
      list[list.length - 1 - i] = temp;
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
        if (char == lfByte) {
          var offset = i;

          if (i > 1 && bts[i - 1] == crByte) offset--;

          position += offset;

          break Outer;
        }

        lineChars.add(char);
      }
    }

    reverseList(lineChars);
    return lineChars;
  }

  Future<List<int>> _readNBytes(int size) {
    var stream = file.openRead(position - size, position);
    var bytes = stream.reduce((previous, element) => previous + element);
    position -= size;
    return bytes;
  }
}
