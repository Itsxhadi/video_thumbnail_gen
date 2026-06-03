package com.itsxhadi.video_thumbnail;

import android.content.Context;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.util.LruCache;

import androidx.annotation.NonNull;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * VideoThumbnailPlugin — Android native implementation.
 *
 * Author : Hadi <hadi7786x@gmail.com>
 * GitHub : https://github.com/Itsxhadi
 * License: MIT
 *
 * Supports: thumbnailData, thumbnailFile, thumbnailDataList, getVideoMetadata, clearCache.
 */
public class VideoThumbnailPlugin implements FlutterPlugin, MethodCallHandler {

    private static final String TAG = "VideoThumbnailPlugin";

    // ─── MethodChannel identifier ─────────────────────────────────────────────
    private static final String CHANNEL = "plugins.itsxhadi.com/video_thumbnail_gen";

    // ─── Error code constants ─────────────────────────────────────────────────
    private static final String ERR_FILE_NOT_FOUND = "FILE_NOT_FOUND";
    private static final String ERR_UNSUPPORTED    = "UNSUPPORTED_FORMAT";
    private static final String ERR_IO             = "IO_ERROR";
    private static final String ERR_UNKNOWN        = "UNKNOWN";

    // ─── Image format indices ─────────────────────────────────────────────────
    private static final int FORMAT_JPEG = 0;
    private static final int FORMAT_PNG  = 1;
    private static final int FORMAT_WEBP = 2;
    private static final int FORMAT_HEIC = 3;

    private Context context;
    private ExecutorService executor;
    private MethodChannel channel;
    private LruCache<String, byte[]> mMemoryCache;

    // ─── FlutterPlugin lifecycle ──────────────────────────────────────────────

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();

        int numCores    = Runtime.getRuntime().availableProcessors();
        int threadCount = Math.max(2, Math.min(4, numCores));
        executor = Executors.newFixedThreadPool(threadCount);

        final int maxMemory = (int) (Runtime.getRuntime().maxMemory() / 1024);
        final int cacheSize = maxMemory / 8;
        mMemoryCache = new LruCache<String, byte[]>(cacheSize) {
            @Override
            protected int sizeOf(String key, byte[] value) {
                return value.length / 1024;
            }
        };

        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        if (executor != null) {
            executor.shutdown();
            executor = null;
        }
        if (mMemoryCache != null) {
            mMemoryCache.evictAll();
            mMemoryCache = null;
        }
    }

    // ─── Method dispatch ──────────────────────────────────────────────────────

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull final Result result) {
        final String method = call.method;

        if (method.equals("clearCache")) {
            if (mMemoryCache != null) mMemoryCache.evictAll();
            runOnUiThread(() -> result.success(null));
            return;
        }

        final Map<String, Object> args = call.arguments();
        final String video   = (String) args.get("video");
        @SuppressWarnings("unchecked")
        final HashMap<String, String> headers = (HashMap<String, String>) args.get("headers");
        final int format  = (int) args.get("format");
        final int maxh    = (int) args.get("maxh");
        final int maxw    = (int) args.get("maxw");
        final int timeMs  = (int) args.get("timeMs");
        final int quality = (int) args.get("quality");

        executor.execute(() -> {
            Object thumbnail = null;
            boolean handled  = false;
            String errCode   = null;
            Exception exc    = null;

            try {
                switch (method) {
                    case "file": {
                        final String path = (String) args.get("path");
                        thumbnail = buildThumbnailFile(video, headers, path, format, maxh, maxw, timeMs, quality);
                        handled = true;
                        break;
                    }
                    case "data": {
                        thumbnail = buildThumbnailData(video, headers, format, maxh, maxw, timeMs, quality);
                        handled = true;
                        break;
                    }
                    case "dataList": {
                        @SuppressWarnings("unchecked")
                        List<Integer> timesMs = (List<Integer>) args.get("timesMs");
                        thumbnail = buildThumbnailDataList(video, headers, timesMs, format, maxh, maxw, quality);
                        handled = true;
                        break;
                    }
                    case "metadata": {
                        thumbnail = getVideoMetadata(video, headers);
                        handled = true;
                        break;
                    }
                }
            } catch (FileNotFoundException e) {
                exc = e; errCode = ERR_FILE_NOT_FOUND;
            } catch (NullPointerException e) {
                exc = e; errCode = ERR_UNSUPPORTED;
            } catch (IOException e) {
                exc = e; errCode = ERR_IO;
            } catch (Exception e) {
                exc = e; errCode = ERR_UNKNOWN;
            }

            final String finalErrCode  = errCode;
            final Exception finalExc   = exc;
            final Object finalThumb    = thumbnail;
            final boolean finalHandled = handled;

            runOnUiThread(() -> {
                if (!finalHandled) { result.notImplemented(); return; }
                if (finalExc != null) {
                    finalExc.printStackTrace();
                    result.error(finalErrCode != null ? finalErrCode : ERR_UNKNOWN,
                                 finalExc.getMessage(), null);
                    return;
                }
                result.success(finalThumb);
            });
        });
    }

    // ─── Format helpers ───────────────────────────────────────────────────────

    @SuppressWarnings("deprecation")
    private static Bitmap.CompressFormat intToFormat(int format) {
        switch (format) {
            case FORMAT_PNG:  return Bitmap.CompressFormat.PNG;
            case FORMAT_WEBP:
                return android.os.Build.VERSION.SDK_INT >= 30
                    ? Bitmap.CompressFormat.WEBP_LOSSY
                    : Bitmap.CompressFormat.WEBP;
            case FORMAT_HEIC:
                // HEIC is not a Bitmap.CompressFormat — fall back to JPEG on all APIs.
                // Actual HEIC encoding is not supported via Bitmap.compress on Android.
                return Bitmap.CompressFormat.JPEG;
            default:
            case FORMAT_JPEG: return Bitmap.CompressFormat.JPEG;
        }
    }

    private static String formatExt(int format) {
        switch (format) {
            case FORMAT_PNG:  return "png";
            case FORMAT_WEBP: return "webp";
            case FORMAT_HEIC: return "heic";
            default:
            case FORMAT_JPEG: return "jpg";
        }
    }

    // ─── Thumbnail data (single frame → memory) ───────────────────────────────

    private byte[] buildThumbnailData(final String vidPath,
                                       final HashMap<String, String> headers,
                                       int format, int maxh, int maxw,
                                       int timeMs, int quality) throws IOException {
        final String cacheKey = vidPath + "_" + timeMs + "_" + format + "_" + maxh + "_" + maxw + "_" + quality;
        if (mMemoryCache != null) {
            byte[] cached = mMemoryCache.get(cacheKey);
            if (cached != null) { Log.d(TAG, "Cache hit: " + cacheKey); return cached; }
        }
        Bitmap bitmap = createVideoThumbnail(vidPath, headers, maxh, maxw, timeMs);
        if (bitmap == null) throw new NullPointerException("Could not decode frame");
        ByteArrayOutputStream stream = new ByteArrayOutputStream();
        bitmap.compress(intToFormat(format), quality, stream);
        bitmap.recycle();
        byte[] bytes = stream.toByteArray();
        if (mMemoryCache != null) mMemoryCache.put(cacheKey, bytes);
        return bytes;
    }

    // ─── Thumbnail file (single frame → disk) ─────────────────────────────────

    private String buildThumbnailFile(final String vidPath,
                                       final HashMap<String, String> headers,
                                       String path,
                                       int format, int maxh, int maxw,
                                       int timeMs, int quality) throws IOException {
        final byte[] bytes = buildThumbnailData(vidPath, headers, format, maxh, maxw, timeMs, quality);
        final String ext   = formatExt(format);

        // Derive the base filename safely — handles both local paths and remote URLs.
        String baseName;
        try {
            String lastSegment = android.net.Uri.parse(vidPath).getLastPathSegment();
            if (lastSegment == null || lastSegment.isEmpty()) lastSegment = "thumbnail";
            final int dotIdx = lastSegment.lastIndexOf('.');
            baseName = (dotIdx >= 0 ? lastSegment.substring(0, dotIdx) : lastSegment) + "." + ext;
        } catch (Exception e) {
            baseName = "thumbnail." + ext;
        }
        String fullpath = baseName;

        final boolean isLocalFile = vidPath.startsWith("/") || vidPath.startsWith("file://");
        if (path == null && !isLocalFile) path = context.getCacheDir().getAbsolutePath();

        if (path != null) {
            File check = new File(path);
            if (check.isDirectory() || path.endsWith("/")) {
                fullpath = path.endsWith("/") ? path + baseName : path + "/" + baseName;
            } else {
                fullpath = path;
            }
        }
        try (FileOutputStream fos = new FileOutputStream(fullpath)) {
            fos.write(bytes);
        }
        Log.d(TAG, String.format("Wrote %d bytes → %s", bytes.length, fullpath));
        return fullpath;
    }

    // ─── Batch frame extraction ───────────────────────────────────────────────

    private List<byte[]> buildThumbnailDataList(final String vidPath,
                                                  final HashMap<String, String> headers,
                                                  final List<Integer> timesMs,
                                                  int format, int maxh, int maxw,
                                                  int quality) throws IOException {
        List<byte[]> results = new ArrayList<>();
        if (timesMs == null || timesMs.isEmpty()) return results;
        Bitmap.CompressFormat cf = intToFormat(format);
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            openRetriever(vidPath, headers, retriever);
            for (int ms : timesMs) {
                Bitmap frame = null;
                try {
                    if (maxh != 0 || maxw != 0) {
                        if (android.os.Build.VERSION.SDK_INT >= 27 && maxh != 0 && maxw != 0) {
                            frame = retriever.getScaledFrameAtTime((long) ms * 1000,
                                    MediaMetadataRetriever.OPTION_CLOSEST, maxw, maxh);
                        } else {
                            frame = retriever.getFrameAtTime((long) ms * 1000,
                                    MediaMetadataRetriever.OPTION_CLOSEST);
                            if (frame != null) frame = scaleAndRecycle(frame, maxh, maxw);
                        }
                    } else {
                        frame = retriever.getFrameAtTime((long) ms * 1000,
                                MediaMetadataRetriever.OPTION_CLOSEST);
                    }
                    if (frame != null) {
                        ByteArrayOutputStream s = new ByteArrayOutputStream();
                        frame.compress(cf, quality, s);
                        results.add(s.toByteArray());
                    } else {
                        results.add(null);
                    }
                } finally {
                    if (frame != null) frame.recycle();
                }
            }
        } finally {
            try { retriever.release(); } catch (Exception ignored) {}
        }
        return results;
    }

    // ─── Video metadata ───────────────────────────────────────────────────────

    private Map<String, Object> getVideoMetadata(final String vidPath,
                                                  final HashMap<String, String> headers) throws IOException {
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            openRetriever(vidPath, headers, retriever);
            String dMs   = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
            String w     = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH);
            String h     = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT);
            String rot   = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION);
            String mime  = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE);
            Map<String, Object> meta = new HashMap<>();
            meta.put("durationMs", dMs  != null ? Long.parseLong(dMs)    : 0L);
            meta.put("width",      w    != null ? Integer.parseInt(w)    : 0);
            meta.put("height",     h    != null ? Integer.parseInt(h)    : 0);
            meta.put("rotation",   rot  != null ? Integer.parseInt(rot)  : 0);
            meta.put("mimeType",   mime);
            return meta;
        } finally {
            try { retriever.release(); } catch (Exception ignored) {}
        }
    }

    // ─── Core frame extraction ────────────────────────────────────────────────

    private Bitmap createVideoThumbnail(final String video,
                                        final HashMap<String, String> headers,
                                        int targetH, int targetW, int timeMs) {
        Bitmap bitmap = null;
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            openRetriever(video, headers, retriever);
            if (targetH != 0 || targetW != 0) {
                if (android.os.Build.VERSION.SDK_INT >= 27 && targetH != 0 && targetW != 0) {
                    bitmap = retriever.getScaledFrameAtTime((long) timeMs * 1000,
                            MediaMetadataRetriever.OPTION_CLOSEST, targetW, targetH);
                } else {
                    bitmap = retriever.getFrameAtTime((long) timeMs * 1000,
                            MediaMetadataRetriever.OPTION_CLOSEST);
                    if (bitmap != null) bitmap = scaleAndRecycle(bitmap, targetH, targetW);
                }
            } else {
                bitmap = retriever.getFrameAtTime((long) timeMs * 1000,
                        MediaMetadataRetriever.OPTION_CLOSEST);
            }
        } catch (RuntimeException | IOException ex) {
            ex.printStackTrace();
        } finally {
            try { retriever.release(); } catch (RuntimeException | IOException ex) { ex.printStackTrace(); }
        }
        return bitmap;
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    private void openRetriever(final String video,
                                final HashMap<String, String> headers,
                                final MediaMetadataRetriever retriever) throws IOException {
        if (video.startsWith("content://")) {
            retriever.setDataSource(context, android.net.Uri.parse(video));
        } else if (video.startsWith("/")) {
            setDataSource(video, retriever);
        } else if (video.startsWith("file://")) {
            setDataSource(video.substring(7), retriever);
        } else {
            retriever.setDataSource(video, headers != null ? headers : new HashMap<>());
        }
    }

    private static Bitmap scaleAndRecycle(Bitmap original, int targetH, int targetW) {
        int w = original.getWidth();
        int h = original.getHeight();
        if (targetW == 0) targetW = Math.round(((float) targetH / h) * w);
        if (targetH == 0) targetH = Math.round(((float) targetW / w) * h);
        Log.d(TAG, String.format("Scaling %dx%d → %dx%d", w, h, targetW, targetH));
        Bitmap scaled = Bitmap.createScaledBitmap(original, targetW, targetH, true);
        if (scaled != original) original.recycle();
        return scaled;
    }

    private static void setDataSource(String video,
                                       final MediaMetadataRetriever retriever) throws IOException {
        File videoFile = new File(video);
        try (FileInputStream inputStream = new FileInputStream(videoFile.getAbsolutePath())) {
            retriever.setDataSource(inputStream.getFD());
        }
    }

    private static void runOnUiThread(Runnable runnable) {
        new Handler(Looper.getMainLooper()).post(runnable);
    }
}
