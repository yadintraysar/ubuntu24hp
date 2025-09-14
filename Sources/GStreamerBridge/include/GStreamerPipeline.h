#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol GStreamerPipelineDelegate <NSObject>
@optional
- (void)gstPipelineDidStart:(NSString *)cameraName;
- (void)gstPipelineDidStop:(NSString *)cameraName;
- (void)gstPipeline:(NSString *)cameraName didError:(NSString *)message;
@end

@interface GStreamerPipeline : NSObject

@property (nonatomic, weak, nullable) id<GStreamerPipelineDelegate> delegate;
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, copy, readonly) NSString *cameraName;
@property (nonatomic, readonly) int port;

+ (void)initializeGStreamer;
+ (void)deinitializeGStreamer;

- (instancetype)initWithCameraName:(NSString *)cameraName port:(int)port;
- (instancetype)initWithCameraName:(NSString *)cameraName port:(int)port useAlternateSoftwareH264:(BOOL)useAlternateSoftwareH264;
- (void)setVideoView:(NSView *)view;
- (BOOL)startPipeline;
- (void)pausePipeline;
- (void)stopPipeline;

- (void)setLatencyMs:(unsigned int)latencyMs;
- (void)setDropOnLatency:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END


