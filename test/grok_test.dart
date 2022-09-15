import 'package:flutter/cupertino.dart';
import 'package:lumberjack/grok/compiler.dart';
import 'package:test/test.dart';

// String testFilePath(String fileName) {
//   return join(Directory.current.path, 'test/util/test_files', fileName);
// }

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('Grok', () {
    test('it matches a simple line', () async {
      var compiler = await defaultCompiler();
      var grok = compiler
          .compile("%{USERNAME:username} %{USERNAME:username2} %{NUMBER}");
      var captures = grok.capture("foobar bin 3");
      expect(
          captures, {"username": "foobar", "username2": "bin", "NUMBER": "3"});
    });
  });
}
