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
      body: LogTable(dataSource: dataSource),
    );
  }
}
