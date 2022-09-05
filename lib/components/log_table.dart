import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../services/log_file_loader.dart';

const double _defaultColumnWidth = 300;

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
  final Map<String, double> _columnWidthOverrides = {};
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

  late String _filePath;
  String get filePath => _filePath;
  set filePath(String path) {
    _filePath = path;
    initLoader();
  }

  LogFileDataSource({
    required String filePath,
  }) {
    this.filePath = filePath;
  }

  void clearCells() {
    _rows.clear();
    _columns.clear();
  }

  Future initLoader() async {
    clearCells();
    _logFileLoader =
        await LogFileLoader.create(_filePath, () => onFileChanged());
    await readMore();
  }

  void onFileChanged() {
    EasyDebounce.debounce('read-forward-debounce',
        const Duration(milliseconds: 100), () => readMore(false));
  }

  final List<DataGridRow> _rows = [];
  final List<String> _columns = [];

  List<String> get columns => _columns;

  @override
  List<DataGridRow> get rows => _rows;

  Future readMore([bool backwards = true]) async {
    if (_logFileLoader == null) return;

    var lines = await _logFileLoader!.readMore(100, backwards);

    if (backwards) {
      _rows.addAll(lines.rows);
    } else {
      for (var row in lines.rows) {
        _rows.insert(0, row);
      }
    }

    _columns.addAll(lines.columns.difference(_columns.toSet()));

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
              border: Border(
                  right: BorderSide(color: Colors.grey.withOpacity(0.5)))),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(4.0),
          child: Text(columnText,
              style: const TextStyle(overflow: TextOverflow.ellipsis)));
    }).toList());
  }
}
