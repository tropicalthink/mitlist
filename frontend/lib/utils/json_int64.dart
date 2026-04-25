import 'package:flutter/foundation.dart';

/// Parses an int64-ish JSON value into a Dart [int].
///
/// On Flutter native, Dart ints are arbitrary precision.
/// On Flutter web, JSON numbers are JS doubles; integers outside 53-bit range
/// cannot be represented without precision loss. In that case we throw.
int parseJsonInt64(dynamic value, {required String fieldName}) {
  if (value == null) {
    throw FormatException('Missing required int field: $fieldName');
  }

  if (value is int) return value;

  if (value is num) {
    if (value % 1 != 0) {
      throw FormatException('Expected integer for $fieldName');
    }
    final asInt = value.toInt();
    if (kIsWeb) {
      const maxSafe = 9007199254740991; // 2^53 - 1
      const minSafe = -9007199254740991;
      if (asInt > maxSafe || asInt < minSafe) {
        throw FormatException('Integer out of safe range for web: $fieldName');
      }
    }
    return asInt;
  }

  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw FormatException('Expected integer string for $fieldName');
    }
    return parsed;
  }

  throw FormatException('Unexpected type for $fieldName');
}

