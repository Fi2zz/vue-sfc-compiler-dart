import 'dart:io';
import 'package:ansicolor/ansicolor.dart';

class _Logger {
  final AnsiPen _pen = AnsiPen();

  void warn(String message) {
    _pen.yellow(bold: true);
    stdout.write(_pen.write('$message\n'));
  }

  void error(String message) {
    _pen.red(bold: true);
    stdout.write(_pen.write('$message\n'));
  }

  void log(String message) {
    _pen.white(bold: true);
    stdout.write(_pen.write('$message\n'));
  }
}

final logger = _Logger();
