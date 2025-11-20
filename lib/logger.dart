import 'dart:io';
import 'package:ansicolor/ansicolor.dart';

class _Logger {
  final AnsiPen _pen = AnsiPen();

  void warn(String message) {
    _pen.yellow(bold: true);
    stdout.write(_pen.write(message));
  }

  void error(String message) {
    _pen.red(bold: true);
    stdout.write(_pen.write(message));
  }
}

final logger = _Logger();
