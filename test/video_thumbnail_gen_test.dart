import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_thumbnail_gen/video_thumbnail_gen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MockHttpOverrides();

  const channel = MethodChannel('plugins.itsxhadi.com/video_thumbnail_gen');

  // ── mock handler ────────────────────────────────────────────────────────────
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      final m = call.method;

      // clearCache has no arguments — handle before casting
      if (m == 'clearCache') return null;

      final Map<dynamic, dynamic> a = call.arguments as Map;

      switch (m) {
        case 'file':
          return 'file=${a["video"]}:${a["path"]}:${a["format"]}:${a["maxh"]}:${a["quality"]}';
        case 'data':
          return Uint8List.fromList([0x01, 0x02, 0x03]); // mock bytes
        case 'dataList':
          final List<int> times = List<int>.from(a['timesMs'] as List);
          return times.map((_) => Uint8List.fromList([0xFF])).toList();
        case 'metadata':
          return <String, dynamic>{
            'durationMs': 5000,
            'width': 1920,
            'height': 1080,
            'rotation': 0,
            'mimeType': 'video/mp4',
          };
        case 'clearCache':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // ── thumbnailFile ───────────────────────────────────────────────────────────
  group('thumbnailFile', () {
    test('returns expected path string', () async {
      final result = await VideoThumbnail.thumbnailFile(
        video: 'video',
        thumbnailPath: 'path',
        imageFormat: ImageFormat.JPEG,
        maxWidth: 123,
        maxHeight: 123,
        quality: 45,
      );
      expect(result, 'file=video:path:0:123:45');
    });

    test('PNG format index is 1', () async {
      final result = await VideoThumbnail.thumbnailFile(
        video: 'video',
        imageFormat: ImageFormat.PNG,
        quality: 80,
      );
      expect(result, contains(':1:')); // format index 1 = PNG
    });

    test('WEBP format index is 2', () async {
      final result = await VideoThumbnail.thumbnailFile(
        video: 'video',
        imageFormat: ImageFormat.WEBP,
        quality: 80,
      );
      expect(result, contains(':2:'));
    });

    test('HEIC format index is 3', () async {
      final result = await VideoThumbnail.thumbnailFile(
        video: 'video',
        imageFormat: ImageFormat.HEIC,
        quality: 80,
      );
      expect(result, contains(':3:'));
    });
  });

  // ── thumbnailData ───────────────────────────────────────────────────────────
  group('thumbnailData', () {
    test('returns Uint8List bytes', () async {
      final bytes = await VideoThumbnail.thumbnailData(
        video: 'video',
        quality: 50,
      );
      expect(bytes, isNotNull);
      expect(bytes, isA<Uint8List>());
      expect(bytes!.length, greaterThan(0));
    });
  });

  // ── thumbnailDataList ───────────────────────────────────────────────────────
  group('thumbnailDataList', () {
    test('returns list with same length as timesMs', () async {
      final frames = await VideoThumbnail.thumbnailDataList(
        video: 'video',
        timesMs: [0, 1000, 2000],
        quality: 75,
      );
      expect(frames.length, 3);
    });

    test('each entry is a Uint8List', () async {
      final frames = await VideoThumbnail.thumbnailDataList(
        video: 'video',
        timesMs: [500],
        quality: 75,
      );
      expect(frames.first, isA<Uint8List>());
    });
  });

  // ── getVideoMetadata ────────────────────────────────────────────────────────
  group('getVideoMetadata', () {
    test('returns VideoMetadata with correct fields', () async {
      final meta = await VideoThumbnail.getVideoMetadata(video: 'video');
      expect(meta, isNotNull);
      expect(meta!.durationMs, 5000);
      expect(meta.width, 1920);
      expect(meta.height, 1080);
      expect(meta.rotation, 0);
      expect(meta.mimeType, 'video/mp4');
    });

    test('VideoMetadata toString is readable', () async {
      final meta = await VideoThumbnail.getVideoMetadata(video: 'video');
      expect(meta.toString(), contains('5000ms'));
      expect(meta.toString(), contains('1920'));
    });
  });

  // ── clearCache ──────────────────────────────────────────────────────────────
  group('clearCache', () {
    test('completes without error', () async {
      await expectLater(VideoThumbnail.clearCache(), completes);
    });
  });

  // ── ThumbnailException ──────────────────────────────────────────────────────
  group('ThumbnailException', () {
    test('maps FILE_NOT_FOUND code correctly', () {
      final ex = ThumbnailException(
        code: ThumbnailErrorCode.fileNotFound,
        message: 'No such file',
      );
      expect(ex.code, ThumbnailErrorCode.fileNotFound);
      expect(ex.message, 'No such file');
      expect(ex.toString(), contains('fileNotFound'));
    });

    test('maps unknown code correctly', () {
      final ex = ThumbnailException(
        code: ThumbnailErrorCode.unknown,
        message: 'Unexpected error',
      );
      expect(ex.code, ThumbnailErrorCode.unknown);
    });
  });

  // ── Input validation ────────────────────────────────────────────────────────
  group('Input validation', () {
    test('thumbnailFile rejects negative maxHeight', () {
      expect(
        () => VideoThumbnail.thumbnailFile(video: 'v', maxHeight: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('thumbnailFile rejects quality > 100', () {
      expect(
        () => VideoThumbnail.thumbnailFile(video: 'v', quality: 101),
        throwsA(isA<AssertionError>()),
      );
    });

    test('thumbnailData rejects negative timeMs', () {
      expect(
        () => VideoThumbnail.thumbnailData(video: 'v', timeMs: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('thumbnailDataList rejects empty timesMs', () {
      expect(
        () => VideoThumbnail.thumbnailDataList(video: 'v', timesMs: []),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ── YouTube URL handling ─────────────────────────────────────────────────────
  group('YouTube URL handling', () {
    final png1x1 = Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      6,
      0,
      0,
      0,
      31,
      21,
      196,
      137,
      0,
      0,
      0,
      10,
      73,
      68,
      65,
      84,
      120,
      156,
      99,
      0,
      1,
      0,
      0,
      5,
      0,
      1,
      13,
      10,
      45,
      180,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130
    ]);

    test('thumbnailData returns mock bytes on YouTube URL', () async {
      final bytes = await VideoThumbnail.thumbnailData(
        video: 'https://youtu.be/Gzz8FwSlsUg?si=4Sfkps4ev2DUXVRR',
      );
      expect(bytes, isNotNull);
      expect(bytes, equals(png1x1));
    });

    test('thumbnailFile downloads and writes image to disk', () async {
      final path = await VideoThumbnail.thumbnailFile(
        video: 'https://youtu.be/Gzz8FwSlsUg?si=4Sfkps4ev2DUXVRR',
      );
      expect(path, isNotNull);
      expect(path, contains('youtube_Gzz8FwSlsUg'));
      final file = File(path!);
      expect(await file.exists(), true);
      expect(await file.readAsBytes(), equals(png1x1));
      // clean up
      await file.delete();
    });

    test('thumbnailData with custom scaling executes successfully', () async {
      final bytes = await VideoThumbnail.thumbnailData(
        video: 'https://youtu.be/Gzz8FwSlsUg?si=4Sfkps4ev2DUXVRR',
        maxWidth: 100,
        maxHeight: 100,
      );
      expect(bytes, isNotNull);
    });
  });
}

// ─── Mock Network overrides ──────────────────────────────────────────────────

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return MockHttpClientRequest();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpClientRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return MockHttpClientResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => 2000;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([
      [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        0,
        0,
        0,
        13,
        73,
        72,
        68,
        82,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        31,
        21,
        196,
        137,
        0,
        0,
        0,
        10,
        73,
        68,
        65,
        84,
        120,
        156,
        99,
        0,
        1,
        0,
        0,
        5,
        0,
        1,
        13,
        10,
        45,
        180,
        0,
        0,
        0,
        0,
        73,
        69,
        78,
        68,
        174,
        66,
        96,
        130
      ]
    ]).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
