import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:lumberjack/grok/compiler.dart';
import 'package:lumberjack/services/log_filter.dart';
import 'package:lumberjack/util/filter_parser/evaluator.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../grok/grok.dart';
import '../logging.dart';
import '../services/log_file_loader.dart';
import '../util/filter_parser/ast.dart';

// TODO: message column can fill the screen if it is the only column.

const double _defaultColumnWidth = 150;

class LogTable extends StatefulWidget {
  const LogTable({
    Key? key,
    required this.dataSource,
    this.onRowSelected,
  }) : super(key: key);

  final LogFileDataSource dataSource;
  final Function(DataGridRow?)? onRowSelected;

  @override
  State<LogTable> createState() => _LogTableState();
}

class _LogTableState extends State<LogTable> {
  final Map<String, double> _columnWidthOverrides = {
    "message": _defaultColumnWidth * 6
  };
  final DataGridController _dataGridController = DataGridController();

  @override
  Widget build(BuildContext context) {
    return SfDataGrid(
        controller: _dataGridController,
        rowHeight: 30,
        headerRowHeight: 50,
        source: widget.dataSource,
        allowColumnsResizing: true,
        columnResizeMode: ColumnResizeMode.onResizeEnd,
        selectionMode: SelectionMode.singleDeselect,
        navigationMode: GridNavigationMode.row,
        onSelectionChanged: (addedRows, removedRows) {
          widget.onRowSelected
              ?.call(addedRows.isEmpty ? null : addedRows.first);
        },
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
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border: BorderDirectional(
                              top: BorderSide(
                                  width: 1.0,
                                  color: Colors.grey.withOpacity(0.5)))),
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
                      decoration: BoxDecoration(
                          border: Border(
                              right: BorderSide(
                                  color: Colors.grey.withOpacity(0.5)))),
                      padding: const EdgeInsets.all(4.0),
                      alignment: Alignment.center,
                      child: Text(c))),
            )
            .toList());
  }
}

class LogFileDataSource extends DataGridSource {
  late File file;
  LogFileLoader? _logFileLoader;
  GrokCompiler? _grokCompiler;
  String? _grokPattern;
  Mode _mode = Mode.plain;

  Mode get mode => _mode;

  late String _filePath;

  String get filePath => _filePath;

  set filePath(String path) {
    _filePath = path;
    initLoader();
  }

  final List<DataGridRow> _sourceRows = [];
  List<DataGridRow> _effectiveRows = [];
  final List<String> _columns = [];

  LogFilter? _filter;

  LogFilter? get filter => _filter;

  set filter(LogFilter? newFilter) {
    if (_filter == newFilter) {
      return;
    }

    _filter = newFilter;
    applyRows();
  }

  List<String> get columns => _columns;

  @override
  List<DataGridRow> get rows => _effectiveRows;

  LogFileDataSource({
    required String filePath,
  }) {
    this.filePath = filePath;
  }

  void clearCells() {
    _sourceRows.clear();
    _columns.clear();
  }

  Future initLoader() async {
    clearCells();

    Grok? grok;
    if (_grokPattern != null && _grokPattern!.isNotEmpty) {
      try {
        _grokCompiler ??= await defaultCompiler();
        grok = _grokCompiler!.compile(_grokPattern!);
      } catch (err) {
        // TODO: Propogate this error to the user.
        log.w("Failed to compile grok pattern: $err");
      }
    }

    _logFileLoader = await LogFileLoader.create(
        _filePath, () => onFileChanged(), _mode, grok);

    try {
      await readMore();
    } catch (err) {
      log.w("Failed to read line from file: $err");
    }
  }

  Future setGrokPattern(String pattern) async {
    _grokPattern = pattern.isEmpty ? null : pattern;
    await initLoader();
  }

  Future setMode(Mode mode) async {
    _mode = mode;
    await initLoader();
  }

  void onFileChanged() {
    EasyDebounce.debounce('read-forward-debounce',
        const Duration(milliseconds: 100), () => readMore(false));
  }

  void applyRows() {
    sortColumns();

    if (filter == null) {
      _effectiveRows = List.from(_sourceRows);
      notifyListeners();
      return;
    }

    _effectiveRows = [];

    for (var row in _sourceRows) {
      if (_filter!.match(row.toMap())) {
        _effectiveRows.add(row);
      }
    }

    notifyListeners();
  }

  Future readMore([bool backwards = true]) async {
    if (_logFileLoader == null) return;

    const linesToLoad = 1000;
    var lines = await _logFileLoader!.readMore(linesToLoad, backwards);

    if (backwards) {
      _sourceRows.addAll(lines.rows);
    } else {
      for (var row in lines.rows) {
        _sourceRows.insert(0, row);
      }
    }

    _columns.addAll(lines.columns.difference(_columns.toSet()));

    applyRows();
  }

  void sortColumns() {
    _columns.sort((a, b) {
      if (a == "message") return 1;
      if (a == "timestamp") return -1;
      return a.compareTo(b);
    });
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
          if (cell.value is Map || cell.value is List) {
            columnText = jsonEncode(cell.value);
          } else {
            columnText = cell.value.toString();
          }
          break;
        }
      }

      return Container(
        height: 30,
        decoration: BoxDecoration(
            border:
                Border(right: BorderSide(color: Colors.grey.withOpacity(0.5)))),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(4.0),
        child: Text(
          columnText,
          style: const TextStyle(overflow: TextOverflow.ellipsis),
        ),
      );
    }).toList());
  }
}

extension RowExt on DataGridRow {
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {};
    for (final cell in getCells()) {
      map[cell.columnName] = cell.value;
    }
    return map;
  }
}
