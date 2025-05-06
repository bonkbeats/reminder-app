import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:intl/intl.dart';

class OcrService {
  /// Processes the image using Google ML Kit's text recognizer and extracts the expiry date.
  static Future<DateTime?> processImage(File image) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = GoogleMlKit.vision.textRecognizer();
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    final rawText = recognizedText.text;
    print('OCR Result:\n$rawText');

    final expiryDate = _extractExpiryDate(rawText);
    await textRecognizer.close();
    return expiryDate;
  }

  /// Extracts the expiry date from the recognized text using regex patterns.
  static DateTime? _extractExpiryDate(String text) {
    final lines = text.split('\n');

    DateTime? fixedExpiry;
    DateTime? mfgDate;
    int? durationMonths;

    // Patterns
    final expiryPatterns = [
      RegExp(
          r'\b(?:EXP|Expires|Expiry|Use by)?[:\s\-]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})\b'),
      RegExp(r'\b(\d{4}[-/]\d{1,2}[-/]\d{1,2})\b'),
    ];
    final mfgPattern = RegExp(
        r'\b(?:MFG|Manufactured)[^\d]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|\d{1,2}[-/]\d{4})');
    final durationPattern = RegExp(
        r'\b(?:Best\s*before|Use\s*within)[^\d]*(\d+)\s*(months|month|years|year)\b',
        caseSensitive: false);

    for (String line in lines) {
      // Check for fixed expiry
      for (var pattern in expiryPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final dateStr = match.group(1);
          final parsed = _tryParseDate(dateStr!);
          if (parsed != null) {
            fixedExpiry = parsed;
            break;
          }
        }
      }

      // Check for MFG
      final mfgMatch = mfgPattern.firstMatch(line);
      if (mfgMatch != null) {
        final dateStr = mfgMatch.group(1);
        mfgDate = _tryParseDate(dateStr!);
      }

      // Check for duration
      final durMatch = durationPattern.firstMatch(line);
      if (durMatch != null) {
        final num = int.tryParse(durMatch.group(1)!);
        final unit = durMatch.group(2)!;
        if (num != null) {
          durationMonths = unit.contains("year") ? num * 12 : num;
        }
      }
    }

    // Use fixed expiry if found
    if (fixedExpiry != null) return fixedExpiry;

    // If MFG + duration is available
    if (mfgDate != null && durationMonths != null) {
      return DateTime(
          mfgDate.year, mfgDate.month + durationMonths, mfgDate.day);
    }

    return null;
  }

  /// Tries to parse a date string using multiple date formats.
  static DateTime? _tryParseDate(String input) {
    final formats = [
      DateFormat('dd/MM/yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('MM-yyyy'),
      DateFormat('MM/yyyy'),
      DateFormat('yyyy/MM/dd'),
      DateFormat('yyyy-MM-dd'),
    ];

    for (var format in formats) {
      try {
        return format.parseStrict(input);
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
