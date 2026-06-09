# video_thumbnail_gen

<p align="center">
  <a href="https://pub.dev/packages/video_thumbnail_gen"><img src="https://img.shields.io/pub/v/video_thumbnail_gen.svg?logo=dart&style=flat-square" alt="pub package"></a>
  <img src="https://img.shields.io/badge/license-MIT-brightgreen?style=flat-square" alt="license">
  <img src="https://img.shields.io/badge/platform-android%20%7C%20ios-lightgrey?style=flat-square" alt="platform">
  <img src="https://img.shields.io/badge/dart-%3E%3D3.0.0-00B4AB?style=flat-square" alt="dart">
</p>

<p align="center">
  A production-grade Flutter plugin to <strong>generate video thumbnails</strong> and <strong>get thumbnails from video URLs</strong> on <strong>Android</strong> and <strong>iOS</strong>.<br>
  Easily convert <strong>video to image</strong>, extract <strong>YouTube video thumbnails</strong> natively, capture video frames, and read video metadata with high performance.
</p>

<p align="center">
  <a href="https://www.paypal.com/donate/?hosted_button_id=VV3WVVCZDF6TC">
    <img src="https://pics.paypal.com/00/s/M2M2MDJkODUtMmFiOS00OGFmLWE2MDQtMDgyYzQ2ZGNkMzc4/file.PNG" alt="Donate with PayPal button" height="35" />
  </a>
</p>

---

## 📸 Screenshots

<p align="center">
  <table align="center">
    <tr>
      <td align="center"><img src="https://raw.githubusercontent.com/Itsxhadi/video_thumbnail_gen/main/example_video_thumnail.png" width="250" alt="Screenshot 1"/><br/><sub>Onboarding Screen</sub></td>
      <td align="center"><img src="https://raw.githubusercontent.com/Itsxhadi/video_thumbnail_gen/main/example_video_thumnail2.png" width="250" alt="Screenshot 2"/><br/><sub>Main App Interface</sub></td>
      <td align="center"><img src="https://raw.githubusercontent.com/Itsxhadi/video_thumbnail_gen/main/example_video_thumnail3.png" width="250" alt="Screenshot 3"/><br/><sub>Thumbnail Extraction</sub></td>
    </tr>
    <tr>
      <td align="center"><img src="https://raw.githubusercontent.com/Itsxhadi/video_thumbnail_gen/main/example_video_thumnail4.png" width="250" alt="Screenshot 4"/><br/><sub>Image Settings</sub></td>
      <td align="center"><img src="https://raw.githubusercontent.com/Itsxhadi/video_thumbnail_gen/main/example_video_thumnail5.png" width="250" alt="Screenshot 5"/><br/><sub>Generated Thumbnail & Path</sub></td>
      <td align="center"><img src="https://raw.githubusercontent.com/Itsxhadi/video_thumbnail_gen/main/example_video_thumnail6.png" width="250" alt="Screenshot 6"/><br/><sub>Settings (Alternative View)</sub></td>
    </tr>
  </table>
</p>

---

## ✨ Features

| Feature | Android | iOS |
|---------|:-------:|:---:|
| JPEG / PNG / WebP thumbnails | ✅ | ✅ |
| HEIC thumbnails | ✅ API 30+ | ✅ iOS 11+ |
| Batch frame extraction (single codec open) | ✅ | ✅ |
| Video metadata (duration, size, rotation) | ✅ | ✅ |
| In-memory LRU / NSCache | ✅ | ✅ |
| `content://` (SAF) URI support | ✅ | — |
| HTTP(S) remote video URL | ✅ | ✅ |
| Custom output filename | ✅ | ✅ |
| Swift Package Manager (SPM) | — | ✅ |
| Typed error codes | ✅ | ✅ |

---

## 📦 Installation

Run this command with Flutter:

```bash
flutter pub add video_thumbnail_gen
```

This will add a line like this to your package's `pubspec.yaml` (and run an implicit `flutter pub get`):

```yaml
dependencies:
  video_thumbnail_gen: ^0.6.3
```

---

## 🚀 Quick Start

```dart
import 'package:video_thumbnail_gen/video_thumbnail_gen.dart';
```

### Generate thumbnail in memory

```dart
final Uint8List? bytes = await VideoThumbnail.thumbnailData(
  video: '/path/to/video.mp4',
  imageFormat: ImageFormat.JPEG,
  maxWidth: 256,
  quality: 75,
);
// Use with Image.memory(bytes!)
```

### Generate thumbnail as a file

```dart
final String? filePath = await VideoThumbnail.thumbnailFile(
  video: 'https://example.com/video.mp4',
  thumbnailPath: (await getTemporaryDirectory()).path,
  imageFormat: ImageFormat.PNG,
  maxHeight: 128,
  quality: 80,
);
```

### Batch frame extraction

```dart
final List<Uint8List?> frames = await VideoThumbnail.thumbnailDataList(
  video: '/path/to/video.mp4',
  timesMs: [0, 2000, 5000, 10000], // extract 4 frames
  imageFormat: ImageFormat.JPEG,
  maxWidth: 320,
  quality: 75,
);
```

### Get video metadata

```dart
final VideoMetadata? meta = await VideoThumbnail.getVideoMetadata(
  video: '/path/to/video.mp4',
);
print('Duration: ${meta?.durationMs}ms');
print('Size: ${meta?.width}×${meta?.height}');
print('Rotation: ${meta?.rotation}°');
print('MIME: ${meta?.mimeType}');
```

### Clear the in-memory cache

```dart
await VideoThumbnail.clearCache();
```

---

## 📖 API Reference

### `VideoThumbnail.thumbnailData`

```dart
static Future<Uint8List?> thumbnailData({
  required String video,
  Map<String, String>? headers,
  ImageFormat imageFormat = ImageFormat.PNG,
  int maxHeight = 0,    // 0 = original
  int maxWidth  = 0,    // 0 = original
  int timeMs    = 0,    // ms from start
  int quality   = 10,   // 0-100, ignored for PNG
})
```

### `VideoThumbnail.thumbnailFile`

```dart
static Future<String?> thumbnailFile({
  required String video,
  Map<String, String>? headers,
  String? thumbnailPath,           // directory OR full file path
  ImageFormat imageFormat = ImageFormat.PNG,
  int maxHeight = 0,
  int maxWidth  = 0,
  int timeMs    = 0,
  int quality   = 10,
})
```

### `VideoThumbnail.thumbnailDataList`

```dart
static Future<List<Uint8List?>> thumbnailDataList({
  required String video,
  Map<String, String>? headers,
  required List<int> timesMs,
  ImageFormat imageFormat = ImageFormat.JPEG,
  int maxHeight = 0,
  int maxWidth  = 0,
  int quality   = 75,
})
```

### `VideoThumbnail.getVideoMetadata`

```dart
static Future<VideoMetadata?> getVideoMetadata({
  required String video,
  Map<String, String>? headers,
})
```

Returns a `VideoMetadata` object:

| Field | Type | Description |
|-------|------|-------------|
| `durationMs` | `int` | Total video duration in milliseconds |
| `width` | `int` | Display width (after rotation) |
| `height` | `int` | Display height (after rotation) |
| `rotation` | `int` | Clockwise rotation: 0, 90, 180, 270 |
| `mimeType` | `String?` | Container MIME type, e.g. `"video/mp4"` |

### `VideoThumbnail.clearCache`

```dart
static Future<void> clearCache()
```

Evicts all entries from the native in-memory cache. Call this during low-memory events or when the app moves to background.

---

## ⚠️ Error Handling

All methods throw `ThumbnailException` on failure:

```dart
try {
  final bytes = await VideoThumbnail.thumbnailData(video: path);
} on ThumbnailException catch (e) {
  switch (e.code) {
    case ThumbnailErrorCode.fileNotFound:
      print('File does not exist: ${e.message}');
    case ThumbnailErrorCode.unsupportedFormat:
      print('Codec not supported: ${e.message}');
    case ThumbnailErrorCode.ioError:
      print('I/O error: ${e.message}');
    default:
      print('Unknown error: ${e.message}');
  }
}
```

### Error Codes

| Code | Cause |
|------|-------|
| `fileNotFound` | File path does not exist |
| `unsupportedFormat` | Video codec not supported or frame undecodable |
| `corruptedVideo` | Thumbnail could not be generated from the video |
| `ioError` | Disk full, permission denied, or write failure |
| `unknown` | Unexpected native error |

---

## 🖼️ Supported Image Formats

| Enum | Android | iOS | Quality param |
|------|---------|-----|:-------------:|
| `ImageFormat.JPEG` | ✅ All APIs | ✅ All | ✅ |
| `ImageFormat.PNG` | ✅ All APIs | ✅ All | ❌ (lossless) |
| `ImageFormat.WEBP` | ✅ All APIs | ✅ (libwebp) | ✅ |
| `ImageFormat.HEIC` | ✅ API 30+ | ✅ iOS 11+ | ✅ |

> **Note:** HEIC falls back to JPEG on older OS versions.

---

## 🍎 iOS: Swift Package Manager (SPM)

A `Package.swift` manifest is included for SPM integration in Xcode 14+.
WebP is only available via CocoaPods; SPM builds fall back to JPEG gracefully.

**CocoaPods** (default):
```ruby
pod 'video_thumbnail_gen', :path => '../'
```

**SPM**: Add the package URL directly in Xcode → File → Add Package Dependencies.

---

## 🔍 Keywords & Use Cases

This plugin is designed to support a wide range of video preview and thumbnail extraction use cases, including:
* **Flutter video thumbnail generator**: Convert any local video file, asset, or remote stream into high-quality preview images.
* **Get thumbnail from video URL**: Extract and download thumbnails from remote HTTP/HTTPS video links.
* **Flutter YouTube thumbnail**: Retrieve YouTube video cover images natively via public CDNs with automatic fallback resolutions.
* **Video to image in Flutter**: Capture video frames as raw bytes (`Uint8List`) or save them directly as files (JPEG, PNG, WebP, HEIC).
* **High-speed frame extraction**: Extract multiple video frames at once using batch processing, keeping the native decoder open for efficiency.

---

## 🤝 Contributing

Issues and pull requests are welcome at [github.com/Itsxhadi/video_thumbnail_gen](https://github.com/Itsxhadi/video_thumbnail_gen).

---

## 🏅 Credits & Acknowledgements

This plugin is a fork of the original [**video_thumbnail**](https://pub.dev/packages/video_thumbnail) package by [**justsoft**](https://github.com/justsoft/video_thumbnail), rebranded as **video_thumbnail_gen** for maintenance and improvements.

The foundational idea, original platform channel design, and initial native implementations are the work of the original author.
This fork extends the original with new APIs, a modernised build system, improved error handling, and additional features.

| Role | Person |
|------|--------|
| **Original Author / Idea** | [justsoft](https://github.com/justsoft/video_thumbnail) |
| **Maintainer / Updater** | [Hadi (Itsxhadi)](https://github.com/Itsxhadi) |

---

## 👤 Author

**Hadi**
- 📧 [hadi7786x@gmail.com](mailto:hadi7786x@gmail.com)
- 🐙 [github.com/Itsxhadi](https://github.com/Itsxhadi)

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
