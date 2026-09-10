import 'dart:io';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/check_coverage.dart <lcov-file> [minimum-percent]',
    );
    exitCode = 64;
    return;
  }

  final file = File(arguments.first);
  final minimum = arguments.length == 2 ? double.tryParse(arguments[1]) : 90.0;

  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: ${file.path}');
    exitCode = 66;
    return;
  }
  if (minimum == null || minimum < 0 || minimum > 100) {
    stderr.writeln('Minimum coverage must be a number from 0 to 100.');
    exitCode = 64;
    return;
  }

  var linesFound = 0;
  var linesHit = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      linesFound += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit += int.parse(line.substring(3));
    }
  }

  if (linesFound == 0) {
    stderr.writeln('The LCOV file contains no executable lines.');
    exitCode = 65;
    return;
  }

  final percentage = linesHit * 100 / linesFound;
  stdout.writeln(
    'Coverage: $linesHit/$linesFound '
    '(${percentage.toStringAsFixed(1)}%), minimum ${minimum.toStringAsFixed(1)}%',
  );

  if (percentage < minimum) {
    exitCode = 1;
  }
}
