import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_repository.dart';

class DatasetUploadResult {
  final int statusCode;
  final String message;

  const DatasetUploadResult({required this.statusCode, required this.message});
}

/// Ported from `researchUpload.ts`. Sends the exported CSV dataset to a
/// research backend as multipart form data, tagged with the same
/// session/trial metadata used for on-device storage. Nothing is sent
/// unless someone configures an endpoint and presses Upload.
class ResearchUploadService {
  final SettingsRepository settings;

  ResearchUploadService(this.settings);

  Future<DatasetUploadResult> uploadCsv({
    required String csvContent,
    required int sampleCount,
  }) async {
    final endpoint = settings.uploadUrl;
    if (endpoint.isEmpty) {
      throw StateError('Dataset upload endpoint is not configured. Set it in Device Settings.');
    }

    final timestamp = DateTime.now().toIso8601String();
    final safeStamp = timestamp.replaceAll(RegExp(r'[:.]'), '-');
    final filename = 'niva_dataset_$safeStamp.csv';

    final request = http.MultipartRequest('POST', Uri.parse(endpoint));

    if (settings.uploadToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${settings.uploadToken}';
    }

    request.files.add(
      http.MultipartFile.fromBytes('file', utf8.encode(csvContent), filename: filename),
    );
    request.fields['sampleCount'] = sampleCount.toString();
    request.fields['generatedAt'] = timestamp;
    request.fields['datasetType'] = 'esp32-biomechanics';
    request.fields['sessionId'] = settings.sessionId;
    request.fields['trialId'] = settings.trialId;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final fallback = response.body.trim().isNotEmpty
          ? response.body
          : 'Upload failed with status ${response.statusCode}.';
      throw Exception(fallback);
    }

    return DatasetUploadResult(
      statusCode: response.statusCode,
      message: 'Dataset uploaded successfully.',
    );
  }
}
