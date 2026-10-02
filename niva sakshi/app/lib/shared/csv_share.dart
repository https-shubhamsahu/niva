import 'dart:convert';
import 'package:share_plus/share_plus.dart';

/// Shares a CSV built in memory. Android opens the share sheet; a browser
/// that cannot share files downloads it instead. No file system needed.
Future<void> shareCsv(String csv, String baseName, String text) {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final name = '$baseName-$stamp.csv';
  return Share.shareXFiles(
      [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: name)],
      fileNameOverrides: [name], text: text);
}
