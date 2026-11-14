import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Holds parsed fields extracted from a Philippine driver's license image.
class LicenseOcrResult {
  final String? lastName;
  final String? firstName;
  final String? middleName;
  final String? address;
  final String? licenseNo;
  final String? expiration;
  final String? nationality;
  final String? bloodType;

  const LicenseOcrResult({
    this.lastName,
    this.firstName,
    this.middleName,
    this.address,
    this.licenseNo,
    this.expiration,
    this.nationality,
    this.bloodType,
  });
}

class LicenseOcrService {
  /// Run OCR on [imagePath] and return parsed license fields.
  static Future<LicenseOcrResult> scan(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognized = await recognizer.processImage(inputImage);
      final text = recognized.text;
      return _parse(text);
    } finally {
      recognizer.close();
    }
  }

  static LicenseOcrResult _parse(String raw) {
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? lastName;
    String? firstName;
    String? middleName;
    String? address;
    String? licenseNo;
    String? expiration;
    String? nationality;
    String? bloodType;

    // ── License number — Philippine format: X##-##-######
    final licenseRegex = RegExp(r'[A-Z]\d{2}-\d{2}-\d{6}');
    final licenseMatch = licenseRegex.firstMatch(raw);
    if (licenseMatch != null) {
      licenseNo = licenseMatch.group(0);
    }

    // ── Date — MM/DD/YYYY or MM-DD-YYYY
    final dateRegex = RegExp(r'\b(\d{2}[\/\-]\d{2}[\/\-]\d{4})\b');
    final dates = dateRegex.allMatches(raw).map((m) => m.group(1)!).toList();
    // Expiration is typically the last date on the license
    if (dates.isNotEmpty) {
      expiration = dates.last.replaceAll('-', '/');
    }

    // ── Blood type
    final btRegex = RegExp(r'\b(A|B|AB|O)[+\-]\b');
    final btMatch = btRegex.firstMatch(raw);
    if (btMatch != null) {
      bloodType = btMatch.group(0);
    }

    // ── Nationality — look for line after "NATIONALITY" label
    for (int i = 0; i < lines.length; i++) {
      final upper = lines[i].toUpperCase();
      if (upper.contains('NATIONALITY') || upper.contains('CITIZENSHIP')) {
        // value may be on same line after colon or next line
        final colonIdx = lines[i].indexOf(':');
        if (colonIdx != -1 && colonIdx < lines[i].length - 1) {
          nationality = lines[i].substring(colonIdx + 1).trim();
        } else if (i + 1 < lines.length) {
          nationality = lines[i + 1].trim();
        }
      }
    }

    // ── Name parsing
    // PH licenses usually have: LAST NAME, FIRST NAME MIDDLE
    // or separate lines for last / first / middle
    final nameRegex = RegExp(r'^([A-Z\s]+),\s*([A-Z\s]+)$');
    for (final line in lines) {
      final match = nameRegex.firstMatch(line);
      if (match != null) {
        lastName = _toTitleCase(match.group(1)!.trim());
        final rest = match.group(2)!.trim().split(RegExp(r'\s+'));
        if (rest.length >= 2) {
          firstName = _toTitleCase(rest.first);
          middleName = _toTitleCase(rest.sublist(1).join(' '));
        } else {
          firstName = _toTitleCase(rest.join(' '));
        }
        break;
      }
    }

    // ── Address — longest line that looks like an address
    // (contains digits + street keywords)
    final addressKeywords = RegExp(
      r'\b(st\.?|ave\.?|blvd\.?|road|rd\.?|street|brgy\.?|barangay|city|quezon|manila|lot|block)\b',
      caseSensitive: false,
    );
    String? bestAddress;
    int bestScore = 0;
    for (final line in lines) {
      if (line.length > 10 && addressKeywords.hasMatch(line)) {
        final score = addressKeywords.allMatches(line).length;
        if (score > bestScore) {
          bestScore = score;
          bestAddress = _toTitleCase(line);
        }
      }
    }
    address = bestAddress;

    return LicenseOcrResult(
      lastName: lastName,
      firstName: firstName,
      middleName: middleName,
      address: address,
      licenseNo: licenseNo,
      expiration: expiration,
      nationality: nationality,
      bloodType: bloodType,
    );
  }

  static String _toTitleCase(String s) {
    return s
        .split(RegExp(r'\s+'))
        .map(
          (w) =>
              w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}
