import 'dart:convert';

Object? sanitizeMojibakeInData(Object? input) {
  if (input is String) {
    return _repairMojibake(input);
  }

  if (input is List) {
    return input.map(sanitizeMojibakeInData).toList();
  }

  if (input is Map) {
    final result = <dynamic, dynamic>{};
    input.forEach((key, value) {
      result[key] = sanitizeMojibakeInData(value);
    });
    return result;
  }

  return input;
}

String _repairMojibake(String value) {
  if (value.isEmpty || !_looksBroken(value)) {
    return value;
  }

  var candidate = value;
  var best = value;
  var bestScore = _score(value);

  for (var i = 0; i < 3; i++) {
    try {
      final bytes = latin1.encode(candidate);
      final decoded = utf8.decode(bytes, allowMalformed: true);
      final decodedScore = _score(decoded);
      if (decodedScore > bestScore) {
        best = decoded;
        bestScore = decodedScore;
      }
      candidate = decoded;
    } catch (_) {
      break;
    }
  }

  return best;
}

bool _looksBroken(String value) {
  const brokenPattern = r'[\u00C2\u00C3\u00D8\u00D9\u00D0\u00D1]';
  final brokenCount = RegExp(brokenPattern).allMatches(value).length;
  final replacementCount = RegExp('\uFFFD').allMatches(value).length;
  final arabicCount = RegExp(r'[\u0600-\u06FF]').allMatches(value).length;

  if (replacementCount > 0) {
    return true;
  }

  return brokenCount >= 2 && arabicCount < (brokenCount * 2);
}

int _score(String value) {
  final arabic = RegExp(r'[\u0600-\u06FF]').allMatches(value).length;
  final broken = RegExp(r'[\u00C2\u00C3\u00D8\u00D9\u00D0\u00D1]').allMatches(value).length;
  final replacement = RegExp('\uFFFD').allMatches(value).length;
  final printable = RegExp(r'[\u0020-\u007E\u0600-\u06FF]').allMatches(value).length;
  return (arabic * 6) + printable - (broken * 8) - (replacement * 12);
}
