import 'dart:math';

/// Generates a standard RFC 4122 version 4 UUID without third-party dependencies.
String generateUuidV4() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(256));

  // Set version to 4 (bits 12-15 of time_hi_and_version to 0100)
  values[6] = (values[6] & 0x0f) | 0x40;
  // Set variant to 1 (bits 6-7 of clock_seq_hi_and_reserved to 10)
  values[8] = (values[8] & 0x3f) | 0x80;

  final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();

  return '${hex[0]}${hex[1]}${hex[2]}${hex[3]}-'
      '${hex[4]}${hex[5]}-'
      '${hex[6]}${hex[7]}-'
      '${hex[8]}${hex[9]}-'
      '${hex[10]}${hex[11]}${hex[12]}${hex[13]}${hex[14]}${hex[15]}';
}
