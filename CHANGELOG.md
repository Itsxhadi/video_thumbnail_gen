## 0.6.2 — 2026-06-03

- Shortened package description in pubspec.yaml to fit within the 60-180 character limit required by pub.dev guidelines.

## 0.6.1 — 2026-06-03

- Update README.md screenshot URLs to use absolute raw GitHub paths to resolve broken images on pub.dev.

## 0.6.0 — 2026-06-03

### 🎉 Initial Release of `video_thumbnail_gen`

First public release of **video_thumbnail_gen**, a modern, production-grade replacement for `video_thumbnail`, maintained by [Hadi](https://github.com/Itsxhadi).
Forked and significantly extended from the original [video_thumbnail](https://pub.dev/packages/video_thumbnail) by justsoft.

#### 🛠️ Fixed Issues & Optimizations
- **iOS WebP Memory Leak**: Fixed a critical memory leak in `VideoThumbnailPlugin.m` where WebP data buffers were not freed. Added `WebPFree(output)` to resolve it.
- **Android File Descriptor Leak**: Wrapped `FileOutputStream` in a try-with-resources statement in `buildThumbnailFile` to prevent unclosed file descriptors.
- **Android Bitmap Memory Leak**: Fixed a memory leak where the original high-resolution bitmap was not recycled after calling `createScaledBitmap`. Introduced a `scaleAndRecycle()` helper.
- **Example App Settings bug**: Resolved duplicate settings widget instantiations in the UI by rebuilding settings dynamically from the Drawer rather than caching stale widgets.
- **Example App UI Cleanliness**: Cleared out the previous thumbnail when a new URL or source is selected, preventing the UI from showing outdated images.
- **Example App Storage & Toast bug**: Fixed storage write issues on Android by requesting appropriate permissions and saving to the correct external storage directory. The app now displays a success toast containing the full file path.
- **Image Format Overflow**: Corrected overflow issues in the format selection menu of the example app.

#### 📣 Community & GitHub Notice
If you run into any issues, have feature requests, or want to contribute optimizations, please **open an issue or pull request** on our GitHub repository: [github.com/Itsxhadi/video_thumbnail_gen](https://github.com/Itsxhadi/video_thumbnail_gen).
I will be regularly maintaining, updating, and reviewing contributions for this package!

#### Core Features
- Generate video thumbnails in memory (`thumbnailData`) or as files (`thumbnailFile`)
- Supports **JPEG**, **PNG**, **WebP**, and **HEIC** output formats
- Custom max width/height with aspect-ratio-preserving scaling
- Capture frame at any timestamp (`timeMs`)
- HTTP(S) remote video URL support with custom headers
- **First-Class YouTube URL Support**: Direct extraction and downloading of thumbnails from the YouTube CDN (uses robust `maxresdefault` ➜ `hqdefault` ➜ `0.jpg` fallback strategy)
- Custom output filename override (pass a full file path to `thumbnailPath`)
- `content://` (SAF) URI support on Android

#### Performance
- **Android**: `LruCache` — 1/8 of heap, keyed by `video+params`
- **iOS**: `NSCache` — 40 MB cap, thread-safe, auto-evicting
- **Batch extraction** (`thumbnailDataList`) — opens codec once, seeks N times
- Thread pool capped to `min(4, availableProcessors)` on Android

#### New APIs
- `VideoThumbnail.getVideoMetadata()` — duration, dimensions, rotation, MIME type
- `VideoThumbnail.thumbnailDataList()` — batch frame extraction
- `VideoThumbnail.clearCache()` — programmatic cache eviction
- `ThumbnailException` + `ThumbnailErrorCode` — typed, machine-readable errors
- `VideoMetadata` — strongly-typed metadata model

#### Native Quality
- iOS: all callbacks dispatched on main thread (no random crashes)
- iOS: `CGBitmapContext` draw approach — handles all `CGImageAlphaInfo` colorspaces
- iOS: `WebPFree(output)` — WebP buffer properly freed after encoding
- Android: `FileOutputStream` in try-with-resources — no FD leaks
- Android: original bitmap recycled immediately after `createScaledBitmap`

#### Platform & Build
- Dart SDK `>=3.0.0`
- Flutter `>=3.0.0`
- Android: Gradle 8+, namespace `com.itsxhadi.video_thumbnail`, `mavenCentral()`
- iOS: deployment target iOS 11+, CocoaPods + **Swift Package Manager** support
- MethodChannel: `plugins.itsxhadi.com/video_thumbnail_gen`
