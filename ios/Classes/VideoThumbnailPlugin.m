#import "VideoThumbnailPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#if __has_include("webp/decode.h") && __has_include("webp/encode.h") && __has_include("webp/demux.h") && __has_include("webp/mux.h")
#import "webp/decode.h"
#import "webp/encode.h"
#import "webp/demux.h"
#import "webp/mux.h"
#define WEBP_AVAILABLE 1
#elif __has_include(<libwebp/decode.h>) && __has_include(<libwebp/encode.h>) && __has_include(<libwebp/demux.h>) && __has_include(<libwebp/mux.h>)
#import <libwebp/decode.h>
#import <libwebp/encode.h>
#import <libwebp/demux.h>
#import <libwebp/mux.h>
#define WEBP_AVAILABLE 1
#else
#define WEBP_AVAILABLE 0
#endif

// ─── Error code constants ──────────────────────────────────────────────────────
static NSString *const kErrFileNotFound    = @"FILE_NOT_FOUND";
static NSString *const kErrUnsupported     = @"UNSUPPORTED_FORMAT";
static NSString *const kErrCorrupted       = @"CORRUPTED_VIDEO";
static NSString *const kErrIO              = @"IO_ERROR";
static NSString *const kErrUnknown         = @"UNKNOWN";

// ─── Image format indices ──────────────────────────────────────────────────────
static const int kFormatJPEG = 0;
static const int kFormatPNG  = 1;
static const int kFormatWEBP = 2;
static const int kFormatHEIC = 3;

// ─── NSCache cost cap (bytes) ──────────────────────────────────────────────────
static const NSUInteger kCacheByteLimit = 40 * 1024 * 1024; // 40 MB

@implementation VideoThumbnailPlugin

// ─── Plugin registration ───────────────────────────────────────────────────────
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel
                                     methodChannelWithName:@"plugins.itsxhadi.com/video_thumbnail_gen"
                                     binaryMessenger:[registrar messenger]];
    VideoThumbnailPlugin *instance = [[VideoThumbnailPlugin alloc] init];
    instance.thumbnailCache = [[NSCache alloc] init];
    instance.thumbnailCache.totalCostLimit = kCacheByteLimit;
    [registrar addMethodCallDelegate:instance channel:channel];
}

// ─── Method dispatch ───────────────────────────────────────────────────────────
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {

    // ── clearCache ──────────────────────────────────────────────────────────────
    if ([@"clearCache" isEqualToString:call.method]) {
        [self.thumbnailCache removeAllObjects];
        dispatch_async(dispatch_get_main_queue(), ^{ result(nil); });
        return;
    }

    NSDictionary *args = call.arguments;

    NSString *file   = args[@"video"];
    NSMutableDictionary *headers = args[@"headers"];
    NSString *path   = args[@"path"];
    int format  = [[args objectForKey:@"format"]  intValue];
    int maxh    = [[args objectForKey:@"maxh"]    intValue];
    int maxw    = [[args objectForKey:@"maxw"]    intValue];
    int timeMs  = [[args objectForKey:@"timeMs"]  intValue];
    int quality = [[args objectForKey:@"quality"] intValue];

    BOOL isLocalFile = [file hasPrefix:@"file://"] || [file hasPrefix:@"/"];

    NSURL *url = [file hasPrefix:@"file://"]
        ? [NSURL fileURLWithPath:[file substringFromIndex:7]]
        : ([file hasPrefix:@"/"] ? [NSURL fileURLWithPath:file] : [NSURL URLWithString:file]);

    // ── data (single frame → memory) ───────────────────────────────────────────
    if ([@"data" isEqualToString:call.method]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *cacheKey = [NSString stringWithFormat:@"%@_%d_%d_%d_%d_%d",
                                  file, timeMs, format, maxh, maxw, quality];
            NSData *cached = [self.thumbnailCache objectForKey:cacheKey];
            if (cached) {
                dispatch_async(dispatch_get_main_queue(), ^{ result(cached); });
                return;
            }

            NSData *data = [VideoThumbnailPlugin generateThumbnail:url
                                                           headers:headers
                                                            format:format
                                                         maxHeight:maxh
                                                          maxWidth:maxw
                                                            timeMs:timeMs
                                                           quality:quality];
            if (data) {
                [self.thumbnailCache setObject:data forKey:cacheKey cost:data.length];
            }
            dispatch_async(dispatch_get_main_queue(), ^{ result(data); });
        });

    // ── dataList (batch frames → memory list) ──────────────────────────────────
    } else if ([@"dataList" isEqualToString:call.method]) {
        NSArray<NSNumber *> *timesMs = args[@"timesMs"];
        if (!timesMs || timesMs.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ result(@[]); });
            return;
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSDictionary *assetOptions = ([headers isEqual:[NSNull null]] || headers == nil)
                ? nil : @{@"AVURLAssetHTTPHeaderFieldsKey": headers};

            AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:assetOptions];
            AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            gen.appliesPreferredTrackTransform = YES;
            gen.maximumSize = CGSizeMake((CGFloat)maxw, (CGFloat)maxh);
            gen.requestedTimeToleranceBefore = kCMTimeZero;
            gen.requestedTimeToleranceAfter  = CMTimeMake(100, 1000);

            NSMutableArray<NSValue *> *cmTimes = [NSMutableArray array];
            for (NSNumber *ms in timesMs) {
                [cmTimes addObject:[NSValue valueWithCMTime:CMTimeMake(ms.intValue, 1000)]];
            }

            __block NSMutableArray<NSData *> *results =
                [NSMutableArray arrayWithCapacity:timesMs.count];
            for (NSInteger i = 0; i < (NSInteger)timesMs.count; i++) {
                [results addObject:[NSNull null]]; // pre-fill with null
            }
            __block NSInteger remaining = (NSInteger)timesMs.count;
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);

            // Build an index map: ms → position in timesMs array
            NSMutableDictionary<NSNumber *, NSNumber *> *indexMap = [NSMutableDictionary dictionary];
            for (NSInteger i = 0; i < (NSInteger)timesMs.count; i++) {
                indexMap[timesMs[i]] = @(i);
            }

            [gen generateCGImagesAsynchronouslyForTimes:cmTimes
                                      completionHandler:^(CMTime rTime,
                                                          CGImageRef cgImage,
                                                          CMTime actualTime,
                                                          AVAssetImageGeneratorResult genResult,
                                                          NSError *error) {
                // Match by requested time using the index map (avoids float rounding)
                NSInteger callIdx = (NSInteger)(CMTimeGetSeconds(rTime) * 1000.0 + 0.5);
                NSNumber *pos = indexMap[@(callIdx)];

                if (pos && genResult == AVAssetImageGeneratorSucceeded && cgImage != NULL) {
                    NSData *data = [VideoThumbnailPlugin encodeImage:cgImage
                                                             format:format
                                                            quality:quality];
                    @synchronized(results) {
                        results[pos.integerValue] = data ?: [NSNull null];
                    }
                }
                if (--remaining <= 0) {
                    dispatch_semaphore_signal(sem);
                }
            }];

            // Timeout after 30 seconds to prevent infinite hang on corrupt video
            dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 30LL * NSEC_PER_SEC));

            // Convert NSNull entries to FlutterNull and send ordered array
            NSMutableArray *ordered = [NSMutableArray array];
            for (id val in results) {
                [ordered addObject:[val isEqual:[NSNull null]] ? [NSNull null] : val];
            }

            dispatch_async(dispatch_get_main_queue(), ^{ result(ordered); });
        });

    // ── file (single frame → disk) ─────────────────────────────────────────────
    } else if ([@"file" isEqualToString:call.method]) {
        if ([path isEqual:[NSNull null]] && !isLocalFile) {
            path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *data = [VideoThumbnailPlugin generateThumbnail:url
                                                           headers:headers
                                                            format:format
                                                         maxHeight:maxh
                                                          maxWidth:maxw
                                                            timeMs:timeMs
                                                           quality:quality];
            if (!data) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    result([FlutterError errorWithCode:kErrCorrupted
                                              message:@"Failed to generate thumbnail"
                                              details:nil]);
                });
                return;
            }

            NSString *ext = (format == kFormatJPEG) ? @"jpg"
                          : (format == kFormatPNG)  ? @"png"
                          : (format == kFormatHEIC) ? @"heic"
                          :                           @"webp";
            NSURL *thumbnail = [[url URLByDeletingPathExtension] URLByAppendingPathExtension:ext];

            if (path && [path isKindOfClass:[NSString class]] && path.length > 0) {
                BOOL isDir = NO;
                [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
                if (isDir || [path hasSuffix:@"/"]) {
                    thumbnail = [[NSURL fileURLWithPath:path]
                                 URLByAppendingPathComponent:[thumbnail lastPathComponent]];
                } else {
                    thumbnail = [NSURL fileURLWithPath:path];
                }
            }

            NSError *writeError = nil;
            if (![data writeToURL:thumbnail options:NSDataWritingAtomic error:&writeError]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    result([FlutterError errorWithCode:kErrIO
                                              message:writeError ? writeError.localizedDescription
                                                                 : @"Failed to write file"
                                              details:nil]);
                });
                return;
            }

            NSString *fullpath = [thumbnail absoluteString];
            dispatch_async(dispatch_get_main_queue(), ^{
                result([fullpath hasPrefix:@"file://"] ? [fullpath substringFromIndex:7] : fullpath);
            });
        });

    // ── metadata ───────────────────────────────────────────────────────────────
    } else if ([@"metadata" isEqualToString:call.method]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSDictionary *assetOptions = ([headers isEqual:[NSNull null]] || headers == nil)
                ? nil : @{@"AVURLAssetHTTPHeaderFieldsKey": headers};

            AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:assetOptions];

            // Duration
            CMTime duration = asset.duration;
            int64_t durationMs = (int64_t)(CMTimeGetSeconds(duration) * 1000.0);

            // Natural size + rotation from first video track
            int videoWidth = 0, videoHeight = 0, rotation = 0;
            NSString *mimeType = nil;

            NSArray<AVAssetTrack *> *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
            if (tracks.count > 0) {
                AVAssetTrack *track = tracks.firstObject;
                CGSize size = track.naturalSize;
                CGAffineTransform t = track.preferredTransform;

                // Derive rotation from transform
                double angle = atan2(t.b, t.a) * (180.0 / M_PI);
                if (angle < 0) angle += 360;
                rotation = (int)round(angle);

                // Swap width/height for 90/270° rotations
                if (rotation == 90 || rotation == 270) {
                    videoWidth  = (int)size.height;
                    videoHeight = (int)size.width;
                } else {
                    videoWidth  = (int)size.width;
                    videoHeight = (int)size.height;
                }

                // MIME type
                NSArray<NSString *> *ids = track.formatDescriptions;
                if (ids.count > 0) {
                    CMFormatDescriptionRef desc = (__bridge CMFormatDescriptionRef)ids[0];
                    CMMediaType mediaType = CMFormatDescriptionGetMediaType(desc);
                    mimeType = (mediaType == kCMMediaType_Video) ? @"video/mp4" : nil;
                }
            }

            NSDictionary *meta = @{
                @"durationMs": @(durationMs),
                @"width":      @(videoWidth),
                @"height":     @(videoHeight),
                @"rotation":   @(rotation),
                @"mimeType":   mimeType ?: [NSNull null],
            };

            dispatch_async(dispatch_get_main_queue(), ^{ result(meta); });
        });

    } else {
        result(FlutterMethodNotImplemented);
    }
}

// ─── Core thumbnail generation ─────────────────────────────────────────────────
+ (NSData *)generateThumbnail:(NSURL *)url
                       headers:(NSMutableDictionary *)headers
                        format:(int)format
                     maxHeight:(int)maxh
                      maxWidth:(int)maxw
                        timeMs:(int)timeMs
                       quality:(int)quality {

    NSDictionary *assetOptions = ([headers isEqual:[NSNull null]] || headers == nil)
        ? nil : @{@"AVURLAssetHTTPHeaderFieldsKey": headers};

    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:assetOptions];
    AVAssetImageGenerator *imgGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];

    imgGenerator.appliesPreferredTrackTransform = YES;
    // Only set maximumSize when dimensions are actually specified
    if (maxw > 0 || maxh > 0) {
        imgGenerator.maximumSize = CGSizeMake((CGFloat)maxw, (CGFloat)maxh);
    }
    imgGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imgGenerator.requestedTimeToleranceAfter  = CMTimeMake(100, 1000);

    NSError *error = nil;
    CGImageRef cgImage = [imgGenerator copyCGImageAtTime:CMTimeMake(timeMs, 1000)
                                              actualTime:nil
                                                   error:&error];
    if (error || cgImage == NULL) {
        NSLog(@"[VideoThumbnailPlugin] generateThumbnail error: %@", error);
        return nil;
    }

    NSData *result = [VideoThumbnailPlugin encodeImage:cgImage format:format quality:quality];
    CGImageRelease(cgImage);
    return result;
}

// ─── Image encoding (JPEG / PNG / WebP / HEIC) ────────────────────────────────
+ (NSData *)encodeImage:(CGImageRef)cgImage format:(int)format quality:(int)quality {
    if (format == kFormatJPEG || format == kFormatPNG) {
        UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
        if (format == kFormatJPEG) {
            return UIImageJPEGRepresentation(uiImage, (CGFloat)(quality * 0.01));
        } else {
            return UIImagePNGRepresentation(uiImage);
        }
    }

    if (format == kFormatHEIC) {
        // HEIC via ImageIO (iOS 11+)
        NSMutableData *heicData = [NSMutableData data];
        CGImageDestinationRef dest = CGImageDestinationCreateWithData(
            (__bridge CFMutableDataRef)heicData,
            (__bridge CFStringRef)@"public.heic",
            1, NULL);
        if (dest) {
            NSDictionary *opts = @{
                (__bridge id)kCGImageDestinationLossyCompressionQuality:
                    @((CGFloat)(quality * 0.01))
            };
            CGImageDestinationAddImage(dest, cgImage, (__bridge CFDictionaryRef)opts);
            CGImageDestinationFinalize(dest);
            CFRelease(dest);
        }
        return heicData.length > 0 ? heicData : nil;
    }

#if WEBP_AVAILABLE
    // WebP via libwebp
    int width  = (int)CGImageGetWidth(cgImage);
    int height = (int)CGImageGetHeight(cgImage);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    int stride = width * 4;
    uint8_t *rawData = (uint8_t *)malloc((size_t)(stride * height));
    if (!rawData) { CGColorSpaceRelease(colorSpace); return nil; }

    CGContextRef ctx = CGBitmapContextCreate(rawData, width, height, 8, stride, colorSpace,
                                             kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);

    size_t retSize = 0;
    uint8_t *output = NULL;

    if (quality == 100) {
        retSize = WebPEncodeLosslessRGBA(rawData, width, height, stride, &output);
    } else {
        retSize = WebPEncodeRGBA(rawData, width, height, stride, (float)quality, &output);
    }

    free(rawData);

    if (retSize == 0 || output == NULL) { return nil; }

    NSData *data = [NSData dataWithBytes:(const void *)output length:retSize];
    WebPFree(output);   // ✅ Bug 1 fixed: free the libwebp-allocated buffer
    return data;
#else
    NSLog(@"[VideoThumbnailPlugin] WebP not available; falling back to JPEG");
    UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
    return UIImageJPEGRepresentation(uiImage, (CGFloat)(quality * 0.01));
#endif
}

@end
