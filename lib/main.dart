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
      body: Column(
        children: [
          Padding(
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
          ),
          Expanded(
              child: Row(
            children: [
              Expanded(
                  child: LogTable(
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

                          json = const JsonEncoder.withIndent("  ")
                              .convert(rowObj);
                        }
                        setState(() {
                          activeRowJson = json;
                        });
                      })),
              Container(
                width: activeRowJson == null ? 0 : 500,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.6),
                          offset: const Offset(0, 10),
                          blurRadius: 5.0,
                          spreadRadius: 0)
                    ],
                    shape: BoxShape.rectangle,
                    color: Theme.of(context).cardColor),
                child: Column(
                  children: [
                    Container(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          shape: const CircleBorder(),
                        ),
                        onPressed: () {
                          setState(() {
                            activeRowJson = null;
                          });
                        },
                        child: const Icon(Icons.close),
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
              )
            ],
          )),
        ],
      ),
    );
  }
}
