import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../logging.dart';
import '../util/reverse_line_reader.dart';

const double _defaultColumnWidth = 300;

class LogTable extends StatefulWidget {
  const LogTable({
    Key? key,
    required this.dataSource,
  }) : super(key: key);

  final LogFileDataSource dataSource;

  @override
  State<LogTable> createState() => _LogTableState();
}

class _LogTableState extends State<LogTable> {
  final Map<String, double> _columnWidthOverrides = {};

  @override
  Widget build(BuildContext context) {
    return SfDataGrid(
        rowHeight: 30,
        headerRowHeight: 50,
        source: widget.dataSource,
        allowColumnsResizing: true,
        columnResizeMode: ColumnResizeMode.onResizeEnd,
        onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
          setState(() {
            _columnWidthOverrides[details.column.columnName] = details.width;
          });
          return true;
        },
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
        columns: widget.dataSource.columns
            .map(
              (c) => GridColumn(
                  columnName: c,
                  width: _columnWidthOverrides[c] ?? _defaultColumnWidth,
                  label: Container(
                      padding: const EdgeInsets.all(4.0),
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

  final List<DataGridRow> _rows = [];
  final List<String> _columns = [];

  List<String> get columns => _columns;

  @override
  List<DataGridRow> get rows => _rows;

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
      var reader = await ReverseLineReader.create(file, lastReadPosBackwards);
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
          height: 30,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(4.0),
          child: Text(columnText));
    }).toList());
  }
}
