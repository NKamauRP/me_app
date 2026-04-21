import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/model_config.dart';

enum DownloadStatus { idle, downloading, completed, failed }

class ModelDownloadService {
  final Dio _dio = Dio();
  
  // Progress tracking via ValueNotifiers to be UI-friendly
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);
  final ValueNotifier<DownloadStatus> status = ValueNotifier<DownloadStatus>(DownloadStatus.idle);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  CancelToken? _cancelToken;

  /// Downloads a model based on its [config].
  /// 
  /// Supports resumption using HTTP Range headers if a partial file exists.
  Future<ModelArtifact> downloadModel(ModelConfig config) async {
    status.value = DownloadStatus.downloading;
    progress.value = 0.0;
    errorMessage.value = null;
    _cancelToken = CancelToken();

    final directory = await _getModelDirectory(config.id);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final fileName = config.downloadUrl.split('/').last;
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);

    int downloadAttempts = 0;
    const maxAttempts = 3;

    while (downloadAttempts < maxAttempts) {
      try {
        downloadAttempts++;
        int existingFileSize = 0;
        if (await file.exists()) {
          existingFileSize = await file.length();
        }

        // 1. Prepare Request with Range header for Resumability
        final options = Options(
          responseType: ResponseType.stream,
          headers: {
            if (existingFileSize > 0) 'Range': 'bytes=$existingFileSize-',
          },
        );

        final response = await _dio.get(
          config.downloadUrl,
          options: options,
          cancelToken: _cancelToken,
        );

        // 2. Handle Stream and Append to File
        final IOSink sink = file.openWrite(mode: FileMode.append);
        final Stream<Uint8List> stream = response.data.stream;
        
        int totalBytes = existingFileSize;
        // Try to get total size from headers
        final contentRange = response.headers.value('content-range');
        int? fullSize;
        if (contentRange != null) {
          fullSize = int.tryParse(contentRange.split('/').last);
        } else {
          final contentLength = response.headers.value('content-length');
          if (contentLength != null) {
            fullSize = int.parse(contentLength) + existingFileSize;
          }
        }

        await for (final chunk in stream) {
          sink.add(chunk);
          totalBytes += chunk.length;
          
          if (fullSize != null && fullSize > 0) {
            progress.value = (totalBytes / fullSize).clamp(0.0, 1.0);
          }
        }

        await sink.flush();
        await sink.close();

        // 3. Validation
        final artifact = await _validateAndCreateArtifact(config, filePath);
        status.value = DownloadStatus.completed;
        return artifact;

      } catch (e) {
        debugPrint('ModelDownloadService: Attempt $downloadAttempts failed: $e');
        
        if (_cancelToken?.isCancelled ?? false) {
          status.value = DownloadStatus.idle;
          rethrow;
        }

        if (downloadAttempts >= maxAttempts) {
          status.value = DownloadStatus.failed;
          errorMessage.value = e.toString();
          
          // Cleanup if corrupted and not resumable
          if (e is DioException && e.response?.statusCode == 416) {
             // Range Not Satisfiable — likely file is already full or corrupted
             if (await file.exists()) await file.delete();
          }
          
          rethrow;
        }
        
        // Brief delay before retry
        await Future.delayed(Duration(seconds: 2 * downloadAttempts));
      }
    }

    throw Exception('Failed to download model after $maxAttempts attempts.');
  }

  void cancel() {
    _cancelToken?.cancel('User cancelled download');
    _cancelToken = null;
    status.value = DownloadStatus.idle;
  }

  Future<Directory> _getModelDirectory(String modelId) async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/models/$modelId');
  }

  Future<ModelArtifact> _validateAndCreateArtifact(ModelConfig config, String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File does not exist after download completion.');
    }

    final size = await file.length();
    if (size == 0) {
      await file.delete();
      throw Exception('Downloaded file is empty (0 bytes).');
    }

    if (config.expectedSize != null && size != config.expectedSize) {
      await file.delete();
      throw Exception('File size mismatch. Expected ${config.expectedSize}, got $size.');
    }

    return ModelArtifact(
      id: config.id,
      name: config.name,
      format: config.format,
      localPath: path,
      sizeInBytes: size,
    );
  }

  Future<bool> isDownloaded(String modelId, String fileName) async {
    final dir = await _getModelDirectory(modelId);
    final file = File('${dir.path}/$fileName');
    return file.exists();
  }
}
