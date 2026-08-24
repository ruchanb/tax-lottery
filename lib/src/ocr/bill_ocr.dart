import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:nepali_utils/nepali_utils.dart';

class BillOcrLine {
  const BillOcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
}

class BillOcrResult {
  const BillOcrResult({
    this.panNumber,
    this.billDateAd,
    this.totalAmount,
  });

  final String? panNumber;
  final String? billDateAd;
  final String? totalAmount;

  int get detectedFieldCount => [panNumber, billDateAd, totalAmount]
      .where((value) => value != null)
      .length;
}

class BillOcrException implements Exception {
  const BillOcrException();

  @override
  String toString() => 'The bill image could not be read.';
}

class BillOcrService {
  const BillOcrService();

  Future<BillOcrResult> scan(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final lines = <BillOcrLine>[];

    try {
      for (final script in [
        TextRecognitionScript.latin,
        TextRecognitionScript.devanagiri,
      ]) {
        final recognizer = TextRecognizer(script: script);
        try {
          final text = await recognizer.processImage(input);
          for (final block in text.blocks) {
            for (final line in block.lines) {
              final box = line.boundingBox;
              lines.add(BillOcrLine(
                text: line.text,
                left: box.left,
                top: box.top,
                width: box.width,
                height: box.height,
              ));
            }
          }
        } finally {
          await recognizer.close();
        }
      }
      return BillOcrParser().parse(lines);
    } catch (_) {
      // Do not expose or log recognized bill text.
      throw const BillOcrException();
    }
  }
}

class BillOcrParser {
  const BillOcrParser();

  BillOcrResult parse(
    List<BillOcrLine> source, {
    DateTime? now,
  }) {
    final lines = [...source]..sort((a, b) {
        final vertical = a.top.compareTo(b.top);
        return vertical == 0 ? a.left.compareTo(b.left) : vertical;
      });
    final normalized =
        lines.map((line) => normalizeOcrDigits(line.text)).toList();
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);

    return BillOcrResult(
      panNumber: _findPan(normalized),
      billDateAd: _findDate(normalized, today),
      totalAmount: _findAmount(normalized),
    );
  }

  static String normalizeOcrDigits(String value) {
    const devanagari = '०१२३४५६७८९';
    var normalized = value;
    for (var i = 0; i < devanagari.length; i++) {
      normalized = normalized.replaceAll(devanagari[i], '$i');
    }
    return normalized.replaceAll('–', '-').replaceAll('—', '-');
  }

  String? _findPan(List<String> lines) {
    final candidates = <_Candidate<String>>[];
    final pattern = RegExp(r'(?:^|[^0-9])([0-9]{9})(?![0-9])');
    final label = RegExp(
      r'pan|vat|pan\s*[/\\-]\s*vat|प्यान|स्थायी\s*लेखा',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      for (final match in pattern.allMatches(lines[i])) {
        final value = match.group(1)!;
        final sameLine = label.hasMatch(lines[i]);
        final nearby = _precedingContext(lines, i, 2);
        final score = sameLine ? 100 : (label.hasMatch(nearby) ? 65 : 10);
        candidates.add(_Candidate(value, score));
      }
    }
    return _confidentBest(candidates, minimumScore: 10);
  }

  String? _findDate(List<String> lines, DateTime today) {
    final candidates = <_Candidate<String>>[];
    final pattern = RegExp(
        r'(?<![0-9])([0-9]{1,4})\s*[-/.]\s*([0-9]{1,2})\s*[-/.]\s*([0-9]{2,4})(?![0-9])');
    final label = RegExp(
      r'bill\s*date|invoice\s*date|date|बिल\s*मिति|मिति',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      for (final match in pattern.allMatches(lines[i])) {
        final date = _parseDateParts(
          match.group(1)!,
          match.group(2)!,
          match.group(3)!,
          today,
        );
        if (date == null) continue;
        final sameLine = label.hasMatch(lines[i]);
        final nearby = _precedingContext(lines, i, 2);
        final score = sameLine ? 100 : (label.hasMatch(nearby) ? 65 : 10);
        candidates.add(_Candidate(_isoDate(date), score));
      }
    }
    return _confidentBest(candidates, minimumScore: 10);
  }

  DateTime? _parseDateParts(
    String first,
    String second,
    String third,
    DateTime today,
  ) {
    final a = int.tryParse(first);
    final b = int.tryParse(second);
    final c = int.tryParse(third);
    if (a == null || b == null || c == null) return null;

    final yearFirst = first.length == 4;
    var year = yearFirst ? a : c;
    final month = b;
    final day = yearFirst ? c : a;
    if (year < 100) year += 2000;

    DateTime converted;
    try {
      if (year >= 2070 && year <= 2100) {
        converted = NepaliDateTime(year, month, day).toDateTime();
      } else {
        if (year < 2000 || year > 2099) return null;
        converted = DateTime(year, month, day);
        if (converted.year != year ||
            converted.month != month ||
            converted.day != day) {
          return null;
        }
      }
    } catch (_) {
      return null;
    }

    final date = DateTime(converted.year, converted.month, converted.day);
    if (date.isAfter(today)) return null;
    return date;
  }

  String? _findAmount(List<String> lines) {
    final candidates = <_Candidate<double>>[];
    final amountPattern =
        RegExp(r'(?<![0-9])([0-9][0-9,]*(?:\.[0-9]{1,2})?)(?![0-9])');
    final totalLabel = RegExp(
      r'grand\s*total|net\s*total|total\s*amount|amount\s*payable|payable|कुल\s*जम्मा|जम्मा|तिर्नुपर्ने|(?:^|\s)total(?:\s|:|$)',
      caseSensitive: false,
    );
    final excluded = RegExp(
      r'sub\s*total|vat|tax|discount|tender|change|छुट|कर',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final sameLine = lines[i];
      final context = _precedingContext(lines, i, 2);
      final hasTotal = totalLabel.hasMatch(sameLine);
      final nearbyTotal = totalLabel.hasMatch(context);
      if (!hasTotal && !nearbyTotal) continue;

      for (final match in amountPattern.allMatches(sameLine)) {
        final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (value == null || value <= 100) continue;
        var score = hasTotal ? 110 : 70;
        if (excluded.hasMatch(sameLine)) score -= 90;
        score += lines.isEmpty ? 0 : ((i / lines.length) * 20).round();
        candidates.add(_Candidate(value, score));
      }
    }

    final value = _confidentBest(candidates, minimumScore: 50);
    if (value == null) return null;
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  String _precedingContext(List<String> lines, int index, int count) {
    final start = index - count < 0 ? 0 : index - count;
    return lines.sublist(start, index + 1).join(' ');
  }

  T? _confidentBest<T>(
    List<_Candidate<T>> candidates, {
    required int minimumScore,
  }) {
    if (candidates.isEmpty) return null;
    final bestByValue = <T, int>{};
    for (final candidate in candidates) {
      final previous = bestByValue[candidate.value];
      if (previous == null || candidate.score > previous) {
        bestByValue[candidate.value] = candidate.score;
      }
    }
    final ranked = bestByValue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.first.value < minimumScore) return null;
    if (ranked.length > 1 && ranked.first.value - ranked[1].value < 15) {
      return null;
    }
    return ranked.first.key;
  }

  String _isoDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _Candidate<T> {
  const _Candidate(this.value, this.score);

  final T value;
  final int score;
}
