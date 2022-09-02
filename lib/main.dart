import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'logging.dart';

// final log = Logger(printer: SimplePrinter(printTime: true));
final log = Logger(printer: JsonPrinter());

void main() {
  log.i("Starting application.");
  runApp(const LumberjackApp());
}

class LumberjackApp extends StatelessWidget {
  const LumberjackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumberjack',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late LogFileDataSource dataSource;

  @override
  void initState() {
    super.initState();
    dataSource = LogFileDataSource(filePath: "/tmp/short-log.jsonl");
    dataSource.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lumberjack'),
      ),
      body: SfDataGrid(
          source: dataSource,
          columnWidthMode: ColumnWidthMode.fill,
          columns: dataSource.columns
              .map(
                (c) => GridColumn(
                    columnName: 'id',
                    label: Container(
                        padding: const EdgeInsets.all(8.0),
                        alignment: Alignment.center,
                        child: Text(c))),
              )
              .toList()),
    );
  }
}

/// An object to set the employee collection data source to the datagrid. This
/// is used to map the employee data to the datagrid widget.
class LogFileDataSource extends DataGridSource {
  /// Creates the employee data source class with required details.
  String filePath;

  LogFileDataSource({required this.filePath}) {
    init();
  }

  Future init() async {
    var file = File(filePath);
    if (!await file.exists()) {
      log.w("File $filePath does not exist.");
      return;
    }

    var lines = await file.readAsLines();
    Set<String> cols = {};

    _rows = lines.reversed.map((l) {
      Map<String, dynamic> rowMap = jsonDecode(l);
      for (var k in rowMap.keys) {
        cols.add(k);
      }
      var cells = rowMap.entries
          .map((entry) =>
              DataGridCell(columnName: entry.key, value: entry.value))
          .toList();
      return DataGridRow(cells: cells);
    }).toList();

    _columns = cols.toList();

    notifyListeners();
  }

  List<DataGridRow> _rows = [];
  List<String> _columns = [];

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
