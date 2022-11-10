import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lumberjack/services/log_file_loader.dart';
import 'package:lumberjack/services/log_filter.dart';

import 'components/log_table.dart';
import 'util/filter_parser/grammar.dart';
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
      darkTheme:
          ThemeData(primarySwatch: Colors.blue, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
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
  late LogFileDataSource _dataSource;
  String? _activeRowJson;
  bool _filterQueryLangEnabled = false;
  final TextEditingController _filterController = TextEditingController();
  final TextEditingController _grokPatternController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataSource = LogFileDataSource(filePath: "/tmp/foo.jsonl");
    _dataSource.addListener(() {
      setState(() {});
    });
  }

  void applyFilter() {
    if (_filterController.text.isEmpty) {
      _dataSource.filter = null;
      return;
    }

    if (_filterQueryLangEnabled) {
      final result = parser.parse(_filterController.text);
      if (result.isFailure) {
        // TODO: Show error msg
        _dataSource.filter = null;
        return;
      }
      _dataSource.filter = ExpressionFilter(result.value);
    } else {
      _dataSource.filter = TextFilter(_filterController.text);
    }
  }

  Future applyGrokPattern() async {
    await _dataSource.setGrokPattern(_grokPatternController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          buildFilePicker(),
          buildFileTypePicker(),
          buildGrokEditor(),
          buildFilterControls(context),
          buildResultsInfoPanel(),
          Expanded(
            child: Row(
              children: [
                Expanded(child: buildLogTable()),
                buildDetailsPanel(context)
              ],
            ),
          ),
        ],
      ),
    );
  }

  Row buildFileTypePicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const Text('File type:'),
        SizedBox(
          width: 150,
          child: ListTile(
            title: const Text('Plain'),
            dense: true,
            leading: Radio<Mode>(
              value: Mode.plain,
              groupValue: _dataSource.mode,
              onChanged: (Mode? value) {
                setState(() {
                  _dataSource.setMode(Mode.plain);
                });
              },
            ),
          ),
        ),
        SizedBox(
          width: 150,
          child: ListTile(
            title: const Text('Json'),
            dense: true,
            leading: Radio<Mode>(
              value: Mode.json,
              groupValue: _dataSource.mode,
              onChanged: (Mode? value) {
                setState(() {
                  _dataSource.setMode(Mode.json);
                });
              },
            ),
          ),
        ),
        // const SizedBox.expand(),
      ],
    );
  }

  Widget buildGrokEditor() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _grokPatternController,
              decoration:
                  const InputDecoration(hintText: "Use GROK pattern..."),
              style: const TextStyle(fontFamily: 'monospace'),
              onEditingComplete: applyGrokPattern,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
              onPressed: applyGrokPattern, child: const Text("Apply"))
        ],
      ),
    );
  }

  // TODO: Count total results from file.
  Widget buildResultsInfoPanel() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 1.0,
            color: Colors.grey.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.0),
            child: Text('${_dataSource.effectiveRows.length} results found'),
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
                _dataSource.filePath = fileResult.files.first.path ?? "";
                _activeRowJson = null;
              });
            },
            child: const Text("Choose file")),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(_dataSource.filePath),
        ),
      ]),
    );
  }

  Widget buildFilterControls(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _filterController,
              decoration: const InputDecoration(hintText: "Filter logs..."),
              style: theme.textTheme.labelLarge?.copyWith(
                fontFamily: 'Roboto Mono',
                fontFamilyFallback: ['monospace'],
              ),
              onEditingComplete: applyFilter,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: """Enable advanced filter query language.
If disabled, the filter will check if the log line contains the provided text.""",
            child: Switch(
              value: _filterQueryLangEnabled,
              onChanged: (val) {
                setState(() {
                  _filterQueryLangEnabled = val;
                  applyFilter();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
              onPressed: () {
                _filterController.clear();
                applyFilter();
              },
              icon: const Icon(Icons.close),
              label: const Text("Clear")),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: applyFilter, child: const Text("Filter"))
        ],
      ),
    );
  }

  Widget buildDetailsPanel(BuildContext context) {
    var theme = Theme.of(context);

    BoxDecoration? decoration;

    if (theme.brightness == Brightness.light) {
      decoration = BoxDecoration(boxShadow: [
        BoxShadow(
            color: Colors.grey.withOpacity(0.6),
            offset: const Offset(0, 10),
            blurRadius: 5.0,
            spreadRadius: 0),
      ], shape: BoxShape.rectangle, color: Theme.of(context).cardColor);
    } else {
      decoration = BoxDecoration(
          shape: BoxShape.rectangle, color: Theme.of(context).backgroundColor);
    }

    return Container(
      width: _activeRowJson == null ? 0 : 500,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.all(10),
      decoration: decoration,
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
                  fixedSize: const Size(28, 28),
                ),
                onPressed: () {
                  setState(() {
                    _activeRowJson = null;
                  });
                },
                child: const Icon(Icons.close),
              ),
            ),
          ),
          SingleChildScrollView(
            child: SelectionArea(
              child: Text(
                _activeRowJson ?? "",
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFamily: 'Roboto Mono',
                  fontFamilyFallback: ['monospace'],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLogTable() {
    return LogTable(
        dataSource: _dataSource,
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
            _activeRowJson = json;
          });
        });
  }
}
