#import <Flutter/Flutter.h>

@interface VideoThumbnailPlugin : NSObject<FlutterPlugin>

/// In-memory thumbnail cache. Thread-safe NSCache keyed by video+params string.
@property (nonatomic, strong) NSCache *thumbnailCache;

@end
