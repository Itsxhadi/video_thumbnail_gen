/// The Flutter plugin for creating thumbnails from video files and URLs.
///
/// To use, import `package:video_thumbnail_gen/video_thumbnail_gen.dart`.
///
/// Supported platforms: **Android**, **iOS**.
///
/// See also:
///  * [video_thumbnail_gen](https://pub.dev/packages/video_thumbnail_gen)
///
library video_thumbnail_gen;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

// ─── Image format ─────────────────────────────────────────────────────────────

/// Supported thumbnail image formats.
///
/// * [JPEG] — lossy, smallest file size; quality parameter applies.
/// * [PNG]  — lossless; quality parameter is ignored.
/// * [WEBP] — lossy on Android / libwebp on iOS; quality parameter applies.
/// * [HEIC] — High Efficiency Image Container (iOS 11+, Android 30+).
///            Falls back to JPEG on older OS versions.
enum ImageFormat { JPEG, PNG, WEBP, HEIC }

// ─── Error codes ──────────────────────────────────────────────────────────────

/// Typed error codes returned inside [ThumbnailException].
enum ThumbnailErrorCode {
  /// The video file path does not exist on disk.
  fileNotFound,

  /// The video format is not supported or the codec is unavailable.
  unsupportedFormat,

  /// The video file is corrupt or the requested frame is undecodable.
  corruptedVideo,

  /// A generic I/O error occurred (e.g. disk full, permission denied).
  ioError,

  /// An unexpected error occurred. Check [ThumbnailException.message] for details.
  unknown;

  /// Convert a platform error code string to a [ThumbnailErrorCode].
  static ThumbnailErrorCode _codeFromString(String? raw) {
    switch (raw) {
      case 'FILE_NOT_FOUND':
        return ThumbnailErrorCode.fileNotFound;
      case 'UNSUPPORTED_FORMAT':
        return ThumbnailErrorCode.unsupportedFormat;
      case 'CORRUPTED_VIDEO':
        return ThumbnailErrorCode.corruptedVideo;
      case 'IO_ERROR':
        return ThumbnailErrorCode.ioError;
      default:
        return ThumbnailErrorCode.unknown;
    }
  }
}

/// Thrown when native thumbnail generation fails.
class ThumbnailException implements Exception {
  /// Machine-readable error code.
  final ThumbnailErrorCode code;

  /// Human-readable description from the native layer.
  final String message;

  const ThumbnailException({required this.code, required this.message});

  @override
  String toString() => 'ThumbnailException(${code.name}): $message';

  /// Convert a platform error code string to a [ThumbnailErrorCode].
  static ThumbnailErrorCode _codeFromString(String? raw) {
    return ThumbnailErrorCode._codeFromString(raw);
  }
}

// ─── Video metadata ───────────────────────────────────────────────────────────

/// Metadata extracted from a video without generating a thumbnail.
class VideoMetadata {
  /// Total video duration in milliseconds.
  final int durationMs;

  /// Video frame width **after** applying rotation (i.e. display width).
  final int width;

  /// Video frame height **after** applying rotation (i.e. display height).
  final int height;

  /// Clockwise rotation in degrees (0, 90, 180 or 270).
  final int rotation;

  /// MIME type reported by the container (e.g. `"video/mp4"`). May be `null`.
  final String? mimeType;

  const VideoMetadata({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.rotation,
    this.mimeType,
  });

  @override
  String toString() =>
      'VideoMetadata(${durationMs}ms, ${width}×${height}, rot:$rotation°, $mimeType)';
}

// ─── Main plugin class ────────────────────────────────────────────────────────

/// Flutter plugin for generating video thumbnails.
class VideoThumbnail {
  static const MethodChannel _channel =
      MethodChannel('plugins.itsxhadi.com/video_thumbnail_gen');

  // ── thumbnailFile ───────────────────────────────────────────────────────────

  /// Generates a thumbnail and writes it to disk, returning the full file path.
  ///
  /// * [video] — local path, `file://` URI, `content://` URI (Android), or HTTP(S) URL.
  /// * [thumbnailPath] — target directory **or** full file path including name.
  ///   If `null` and [video] is a local file, the thumbnail is placed next to it.
  ///   If `null` and [video] is a remote URL, the system cache directory is used.
  /// * [imageFormat] — output image format (default [ImageFormat.PNG]).
  /// * [maxHeight] / [maxWidth] — maximum dimensions; `0` means original size.
  /// * [timeMs] — position in the video from which to extract the frame (ms).
  /// * [quality] — compression quality 0–100 (ignored for PNG).
  ///
  /// Throws [ThumbnailException] on failure.
  static Future<String?> thumbnailFile({
    required String video,
    Map<String, String>? headers,
    String? thumbnailPath,
    ImageFormat imageFormat = ImageFormat.PNG,
    int maxHeight = 0,
    int maxWidth = 0,
    int timeMs = 0,
    int quality = 10,
  }) async {
    assert(video.isNotEmpty, 'video must not be empty');
    assert(maxHeight >= 0, 'maxHeight must be non-negative');
    assert(maxWidth >= 0, 'maxWidth must be non-negative');
    assert(quality >= 0 && quality <= 100, 'quality must be between 0 and 100');
    assert(timeMs >= 0, 'timeMs must be non-negative');

    if (video.isEmpty) return null;

    final youtubeId = _extractYoutubeId(video);
    if (youtubeId != null) {
      try {
        var bytes = await _fetchYoutubeThumbnailBytes(youtubeId, headers);
        if (bytes == null) {
          throw const ThumbnailException(
            code: ThumbnailErrorCode.unknown,
            message: 'Failed to download YouTube thumbnail image',
          );
        }

        if (maxHeight > 0 || maxWidth > 0) {
          bytes = await _scaleImage(bytes, maxWidth, maxHeight);
        }

        String fullpath;
        final ext = imageFormat == ImageFormat.PNG
            ? 'png'
            : (imageFormat == ImageFormat.WEBP ? 'webp' : 'jpg');
        final baseName = 'youtube_$youtubeId.$ext';

        if (thumbnailPath != null) {
          final check = Directory(thumbnailPath);
          if (await check.exists()) {
            fullpath = thumbnailPath.endsWith('/')
                ? '$thumbnailPath$baseName'
                : '$thumbnailPath/$baseName';
          } else {
            fullpath = thumbnailPath;
          }
        } else {
          final tempDir = Directory.systemTemp;
          fullpath = '${tempDir.path}/$baseName';
        }

        final file = File(fullpath);
        await file.writeAsBytes(bytes);
        return fullpath;
      } catch (e) {
        if (e is ThumbnailException) rethrow;
        throw ThumbnailException(
          code: ThumbnailErrorCode.unknown,
          message: e.toString(),
        );
      }
    }

    try {
      return await _channel.invokeMethod<String>('file', <String, dynamic>{
        'video': video,
        'headers': headers,
        'path': thumbnailPath,
        'format': imageFormat.index,
        'maxh': maxHeight,
        'maxw': maxWidth,
        'timeMs': timeMs,
        'quality': quality,
      });
    } on PlatformException catch (e) {
      throw ThumbnailException(
        code: ThumbnailException._codeFromString(e.code),
        message: e.message ?? e.toString(),
      );
    }
  }

  // ── thumbnailData ───────────────────────────────────────────────────────────

  /// Generates a thumbnail and returns it as raw bytes in memory.
  ///
  /// The returned [Uint8List] can be passed directly to `Image.memory(...)`.
  ///
  /// Throws [ThumbnailException] on failure.
  static Future<Uint8List?> thumbnailData({
    required String video,
    Map<String, String>? headers,
    ImageFormat imageFormat = ImageFormat.PNG,
    int maxHeight = 0,
    int maxWidth = 0,
    int timeMs = 0,
    int quality = 10,
  }) async {
    assert(video.isNotEmpty, 'video must not be empty');
    assert(maxHeight >= 0, 'maxHeight must be non-negative');
    assert(maxWidth >= 0, 'maxWidth must be non-negative');
    assert(quality >= 0 && quality <= 100, 'quality must be between 0 and 100');
    assert(timeMs >= 0, 'timeMs must be non-negative');

    final youtubeId = _extractYoutubeId(video);
    if (youtubeId != null) {
      try {
        var bytes = await _fetchYoutubeThumbnailBytes(youtubeId, headers);
        if (bytes == null) {
          throw const ThumbnailException(
            code: ThumbnailErrorCode.unknown,
            message: 'Failed to download YouTube thumbnail image',
          );
        }
        if (maxHeight > 0 || maxWidth > 0) {
          bytes = await _scaleImage(bytes, maxWidth, maxHeight);
        }
        return bytes;
      } catch (e) {
        if (e is ThumbnailException) rethrow;
        throw ThumbnailException(
          code: ThumbnailErrorCode.unknown,
          message: e.toString(),
        );
      }
    }

    try {
      return await _channel.invokeMethod<Uint8List>('data', <String, dynamic>{
        'video': video,
        'headers': headers,
        'format': imageFormat.index,
        'maxh': maxHeight,
        'maxw': maxWidth,
        'timeMs': timeMs,
        'quality': quality,
      });
    } on PlatformException catch (e) {
      throw ThumbnailException(
        code: ThumbnailException._codeFromString(e.code),
        message: e.message ?? e.toString(),
      );
    }
  }

  // ── thumbnailDataList ───────────────────────────────────────────────────────

  /// Extracts multiple frames from [video] at the given [timesMs] positions
  /// and returns them as a list of byte arrays, in the same order.
  ///
  /// More efficient than calling [thumbnailData] repeatedly because the native
  /// layer opens the video file/codec **once** and seeks to each timestamp.
  ///
  /// Entries may be `null` if a specific frame could not be decoded.
  ///
  /// Throws [ThumbnailException] on a global failure.
  static Future<List<Uint8List?>> thumbnailDataList({
    required String video,
    Map<String, String>? headers,
    required List<int> timesMs,
    ImageFormat imageFormat = ImageFormat.JPEG,
    int maxHeight = 0,
    int maxWidth = 0,
    int quality = 75,
  }) async {
    assert(video.isNotEmpty, 'video must not be empty');
    assert(timesMs.isNotEmpty, 'timesMs must not be empty');
    assert(maxHeight >= 0, 'maxHeight must be non-negative');
    assert(maxWidth >= 0, 'maxWidth must be non-negative');
    assert(quality >= 0 && quality <= 100, 'quality must be between 0 and 100');

    try {
      final raw = await _channel
          .invokeListMethod<Object?>('dataList', <String, dynamic>{
        'video': video,
        'headers': headers,
        'timesMs': timesMs,
        'format': imageFormat.index,
        'maxh': maxHeight,
        'maxw': maxWidth,
        'quality': quality,
      });
      return (raw ?? []).map((e) => e is Uint8List ? e : null).toList();
    } on PlatformException catch (e) {
      throw ThumbnailException(
        code: ThumbnailException._codeFromString(e.code),
        message: e.message ?? e.toString(),
      );
    }
  }

  // ── getVideoMetadata ────────────────────────────────────────────────────────

  /// Retrieves video metadata (duration, dimensions, rotation, MIME type)
  /// **without** generating a thumbnail.
  ///
  /// Returns `null` if the video cannot be opened.
  /// Throws [ThumbnailException] on a hard failure.
  static Future<VideoMetadata?> getVideoMetadata({
    required String video,
    Map<String, String>? headers,
  }) async {
    assert(video.isNotEmpty, 'video must not be empty');

    final youtubeId = _extractYoutubeId(video);
    if (youtubeId != null) {
      return const VideoMetadata(
        durationMs: 0,
        width: 1280,
        height: 720,
        rotation: 0,
        mimeType: 'video/youtube',
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'metadata',
        <String, dynamic>{
          'video': video,
          'headers': headers,
          // Dummy fields to keep native argument parsing happy
          'format': 0,
          'maxh': 0,
          'maxw': 0,
          'timeMs': 0,
          'quality': 0,
        },
      );
      if (result == null) return null;
      return VideoMetadata(
        durationMs: (result['durationMs'] as num?)?.toInt() ?? 0,
        width: (result['width'] as num?)?.toInt() ?? 0,
        height: (result['height'] as num?)?.toInt() ?? 0,
        rotation: (result['rotation'] as num?)?.toInt() ?? 0,
        mimeType: result['mimeType'] as String?,
      );
    } on PlatformException catch (e) {
      throw ThumbnailException(
        code: ThumbnailException._codeFromString(e.code),
        message: e.message ?? e.toString(),
      );
    }
  }

  // ── clearCache ──────────────────────────────────────────────────────────────

  /// Evicts all cached thumbnails from the native in-memory cache.
  ///
  /// Call this when the app moves to the background or is under memory pressure.
  static Future<void> clearCache() async {
    await _channel.invokeMethod<void>('clearCache');
  }

  // ── Private helpers for YouTube URLs ──────────────────────────────────────────

  static String? _extractYoutubeId(String url) {
    final regExp = RegExp(
      r'^.*(?:(?:youtu\.be\/|v\/|vi\/|u\/\w\/|embed\/|shorts\/)|(?:(?:watch)?\?v(?:i)?=|\&v(?:i)?=))([^#\&\?]*).*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final id = match.group(1);
      if (id != null && id.length == 11) {
        return id;
      }
    }
    return null;
  }

  static Future<Uint8List?> _fetchYoutubeThumbnailBytes(
      String videoId, Map<String, String>? headers) async {
    final urls = [
      'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      'https://img.youtube.com/vi/$videoId/0.jpg',
    ];

    final client = HttpClient();
    for (final url in urls) {
      try {
        final request = await client.getUrl(Uri.parse(url));
        if (headers != null) {
          headers.forEach((key, val) => request.headers.add(key, val));
        }
        final response = await request.close();
        if (response.statusCode == 200) {
          if (response.contentLength > 1500 || url == urls.last) {
            final builder = BytesBuilder();
            await for (final chunk in response) {
              builder.add(chunk);
            }
            final bytes = builder.takeBytes();
            if (bytes.isNotEmpty) return bytes;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<Uint8List> _scaleImage(
      Uint8List bytes, int maxWidth, int maxHeight) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final originalW = frame.image.width;
      final originalH = frame.image.height;

      int targetW = maxWidth;
      int targetH = maxHeight;

      if (targetW == 0 && targetH > 0) {
        targetW = ((targetH / originalH) * originalW).round();
      } else if (targetH == 0 && targetW > 0) {
        targetH = ((targetW / originalW) * originalH).round();
      } else if (targetW > 0 && targetH > 0) {
        final double scale = (targetW / originalW < targetH / originalH)
            ? (targetW / originalW)
            : (targetH / originalH);
        targetW = (originalW * scale).round();
        targetH = (originalH * scale).round();
      } else {
        return bytes;
      }

      final scaleCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final scaledFrame = await scaleCodec.getNextFrame();
      final byteData =
          await scaledFrame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (_) {}
    return bytes;
  }
}
