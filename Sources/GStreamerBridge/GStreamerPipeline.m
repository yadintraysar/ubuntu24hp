#import "GStreamerPipeline.h"

#include <gst/gst.h>
#include <gst/video/videooverlay.h>

@interface GStreamerPipeline () {
    GstElement *_pipeline;
    GstElement *_udpsrc;
    GstElement *_jitter;
    GstElement *_depay;
    GstElement *_parse;
    GstElement *_decoder;
    GstElement *_videoconvert;
    GstElement *_queueAfterDecode;
    GstElement *_sink;
    GMainLoop *_loop;
    GThread *_thread;
    BOOL _isPlaying;
    __weak NSView *_view;
    BOOL _useAlternateSoftwareH264;
}
@end

static gpointer gst_main_loop_thread(gpointer data) {
    GMainLoop *loop = (GMainLoop *)data;
    g_main_loop_run(loop);
    return NULL;
}

static gboolean bus_callback(GstBus *bus, GstMessage *msg, gpointer user_data) {
    GStreamerPipeline *self = (__bridge GStreamerPipeline *)user_data;
    switch (GST_MESSAGE_TYPE(msg)) {
        case GST_MESSAGE_ERROR: {
            GError *err = NULL; gchar *dbg = NULL;
            gst_message_parse_error(msg, &err, &dbg);
            NSString *m = err ? [NSString stringWithUTF8String:err->message] : @"unknown";
            if ([self.delegate respondsToSelector:@selector(gstPipeline:didError:)]) {
                [self.delegate gstPipeline:self.cameraName didError:m];
            }
            if (err) g_error_free(err); if (dbg) g_free(dbg);
            break;
        }
        case GST_MESSAGE_EOS:
            if ([self.delegate respondsToSelector:@selector(gstPipelineDidStop:)]) {
                [self.delegate gstPipelineDidStop:self.cameraName];
            }
            break;
        default:
            break;
    }
    return TRUE;
}

@implementation GStreamerPipeline

+ (void)initializeGStreamer {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        int argc = 0; char **argv = NULL; gst_init(&argc, &argv);
    });
}

+ (void)deinitializeGStreamer {
    // No-op
}

- (instancetype)initWithCameraName:(NSString *)cameraName port:(int)port {
    return [self initWithCameraName:cameraName port:port useAlternateSoftwareH264:NO];
}

- (instancetype)initWithCameraName:(NSString *)cameraName port:(int)port useAlternateSoftwareH264:(BOOL)useAlternateSoftwareH264 {
    if (self = [super init]) {
        _cameraName = [cameraName copy];
        _port = port;
        _useAlternateSoftwareH264 = useAlternateSoftwareH264;
        _loop = g_main_loop_new(NULL, FALSE);
        _thread = g_thread_new("gst-main", gst_main_loop_thread, _loop);

        _udpsrc = gst_element_factory_make("udpsrc", NULL);
        _jitter = gst_element_factory_make("rtpjitterbuffer", NULL);
        _depay = gst_element_factory_make("rtph264depay", NULL);
        _parse = gst_element_factory_make("h264parse", NULL);
        _decoder = gst_element_factory_make(useAlternateSoftwareH264 ? "avdec_h264" : "vtdec", NULL);
        _videoconvert = useAlternateSoftwareH264 ? gst_element_factory_make("videoconvert", NULL) : NULL;
        _queueAfterDecode = gst_element_factory_make("queue", NULL);
        _sink = gst_element_factory_make("glimagesink", "sink");
        _pipeline = gst_pipeline_new("pipeline");

        if (!_pipeline || !_udpsrc || !_depay || !_parse || !_decoder || !_queueAfterDecode || !_sink || !_jitter || (useAlternateSoftwareH264 && !_videoconvert)) {
            NSLog(@"Failed to create GStreamer elements");
            return self;
        }

        const char *capsStr = useAlternateSoftwareH264
            ? "application/x-rtp,media=video,encoding-name=H264,payload=96"
            : "application/x-rtp,payload=96,clock-rate=90000";
        GstCaps *caps = gst_caps_from_string(capsStr);
        g_object_set(G_OBJECT(_udpsrc), "port", _port, NULL);
        g_object_set(G_OBJECT(_udpsrc), "caps", caps, NULL);
        gst_caps_unref(caps);

        g_object_set(G_OBJECT(_jitter), "latency", 60, NULL);
        g_object_set(G_OBJECT(_jitter), "drop-on-latency", TRUE, NULL);
        g_object_set(G_OBJECT(_sink), "sync", FALSE, NULL);

        if (useAlternateSoftwareH264) {
            gst_bin_add_many(GST_BIN(_pipeline), _udpsrc, _jitter, _depay, _parse, _decoder, _queueAfterDecode, _videoconvert, _sink, NULL);
            if (!gst_element_link(_udpsrc, _jitter) ||
                !gst_element_link(_jitter, _depay) ||
                !gst_element_link(_depay, _parse) ||
                !gst_element_link(_parse, _decoder) ||
                !gst_element_link(_decoder, _queueAfterDecode) ||
                !gst_element_link(_queueAfterDecode, _videoconvert) ||
                !gst_element_link(_videoconvert, _sink)) {
                NSLog(@"Failed to link alternate GStreamer pipeline");
            }
        } else {
            gst_bin_add_many(GST_BIN(_pipeline), _udpsrc, _jitter, _depay, _parse, _decoder, _queueAfterDecode, _sink, NULL);
            if (!gst_element_link(_udpsrc, _jitter) ||
                !gst_element_link(_jitter, _depay) ||
                !gst_element_link(_depay, _parse) ||
                !gst_element_link(_parse, _decoder) ||
                !gst_element_link(_decoder, _queueAfterDecode) ||
                !gst_element_link(_queueAfterDecode, _sink)) {
                NSLog(@"Failed to link GStreamer pipeline");
            }
        }

        GstBus *bus = gst_element_get_bus(_pipeline);
        GSource *bus_source = gst_bus_create_watch(bus);
        g_source_set_callback(bus_source, (GSourceFunc)bus_callback, (__bridge void *)self, NULL);
        g_source_attach(bus_source, NULL);
        g_source_unref(bus_source);
        gst_object_unref(bus);
    }
    return self;
}

- (void)setVideoView:(NSView *)view {
    _view = view;
    if (_sink && view) {
        gst_video_overlay_set_window_handle(GST_VIDEO_OVERLAY(_sink), (guintptr)view);
    }
}

- (BOOL)startPipeline {
    GstStateChangeReturn ret = gst_element_set_state(_pipeline, GST_STATE_PLAYING);
    _isPlaying = (ret != GST_STATE_CHANGE_FAILURE);
    if (_isPlaying && [self.delegate respondsToSelector:@selector(gstPipelineDidStart:)]) {
        [self.delegate gstPipelineDidStart:self.cameraName];
    }
    return _isPlaying;
}

- (void)pausePipeline {
    gst_element_set_state(_pipeline, GST_STATE_PAUSED);
    _isPlaying = NO;
}

- (void)stopPipeline {
    gst_element_set_state(_pipeline, GST_STATE_NULL);
    _isPlaying = NO;
    if ([self.delegate respondsToSelector:@selector(gstPipelineDidStop:)]) {
        [self.delegate gstPipelineDidStop:self.cameraName];
    }
}

- (void)setLatencyMs:(unsigned int)latencyMs {
    g_object_set(G_OBJECT(_jitter), "latency", latencyMs, NULL);
}

- (void)setDropOnLatency:(BOOL)enabled {
    g_object_set(G_OBJECT(_jitter), "drop-on-latency", enabled ? TRUE : FALSE, NULL);
}

- (BOOL)isPlaying { return _isPlaying; }

- (void)dealloc {
    [self stopPipeline];
    if (_loop) { g_main_loop_quit(_loop); }
    if (_thread) { g_thread_join(_thread); _thread = NULL; }
    if (_loop) { g_main_loop_unref(_loop); _loop = NULL; }
    if (_pipeline) { gst_object_unref(_pipeline); _pipeline = NULL; }
}

@end


