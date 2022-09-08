import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'components/log_table.dart';
import 'logging.dart';

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
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late LogFileDataSource dataSource;
  String? activeRowJson;
  TextEditingController filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    dataSource = LogFileDataSource(filePath: "/tmp/short-log.jsonl");
    dataSource.addListener(() {
      setState(() {});
    });
  }

  void applyFilter() {
    dataSource.filter = filterController.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          buildFilePicker(),
          buildFilterControls(),
          buildResultsInfoPanel(),
          Expanded(
              child: Row(
            children: [
              Expanded(child: buildLogTable()),
              buildDetailsPanel(context)
            ],
          )),
        ],
      ),
    );
  }

  // TODO: Count total results from file.
  Widget buildResultsInfoPanel() {
    return Container(
      decoration: BoxDecoration(
          border: Border(
        bottom: BorderSide(width: 1.0, color: Colors.grey.withOpacity(0.5)),
      )),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.0),
            child: Text('${dataSource.effectiveRows.length} results found'),
          )
        ],
      ),
    );
  }

  Widget buildFilePicker() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(children: [
        ElevatedButton(
            onPressed: () async {
              var fileResult = await FilePicker.platform.pickFiles();
              if (fileResult == null || fileResult.files.isEmpty) return;
              setState(() {
                dataSource.filePath = fileResult.files.first.path ?? "";
                activeRowJson = null;
              });
            },
            child: const Text("Choose file")),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(dataSource.filePath),
        ),
      ]),
    );
  }

  Widget buildFilterControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: filterController,
              decoration: const InputDecoration(hintText: "Filter logs..."),
              onEditingComplete: applyFilter,
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
              onPressed: () {
                filterController.clear();
                applyFilter();
              },
              icon: const Icon(Icons.close),
              label: const Text("Clear")),
          const SizedBox(width: 10),
          ElevatedButton(onPressed: applyFilter, child: const Text("Filter"))
        ],
      ),
    );
  }

  Widget buildDetailsPanel(BuildContext context) {
    return Container(
      width: activeRowJson == null ? 0 : 500,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(boxShadow: [
        BoxShadow(
            color: Colors.grey.withOpacity(0.6),
            offset: const Offset(0, 10),
            blurRadius: 5.0,
            spreadRadius: 0)
      ], shape: BoxShape.rectangle, color: Theme.of(context).cardColor),
      child: Column(
        children: [
          Container(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 28,
              height: 28,
              child: TextButton(
                style: TextButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    fixedSize: const Size(28, 28)),
                onPressed: () {
                  setState(() {
                    activeRowJson = null;
                  });
                },
                child: const Icon(Icons.close),
              ),
            ),
          ),
          SingleChildScrollView(
              child: SelectionArea(
                  child: Text(
            activeRowJson ?? "",
            style: const TextStyle(fontFamily: 'monospace'),
          ))),
        ],
      ),
    );
  }

  Widget buildLogTable() {
    return LogTable(
        dataSource: dataSource,
        onRowSelected: (row) {
          String? json;
          if (row == null) {
            json = null;
          } else {
            Map<String, dynamic> rowObj = {};
            for (var cell in row.getCells()) {
              rowObj[cell.columnName] = cell.value;
            }

            json = const JsonEncoder.withIndent("  ").convert(rowObj);
          }
          setState(() {
            activeRowJson = json;
          });
        });
  }
}
