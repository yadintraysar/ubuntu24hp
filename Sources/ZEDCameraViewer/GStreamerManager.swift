import Foundation
import AppKit
import GStreamerBridge

class GStreamerManager: NSObject {
    static let shared = GStreamerManager()
    
    private var pipelines: [String: GStreamerPipeline] = [:]
    
    override init() {
        super.init()
        GStreamerPipeline.initializeGStreamer()
    }
    
    deinit {
        stopAllStreams()
        GStreamerPipeline.deinitializeGStreamer()
    }
    
    func createPipeline(for config: CameraConfig, videoView: NSView, delegate: GStreamerPipelineDelegate) -> Bool {
        let key = config.name
        
        // Stop existing pipeline if any
        if let existingPipeline = pipelines[key] {
            existingPipeline.stop()
            pipelines.removeValue(forKey: key)
        }
        
        // Create new pipeline
        let pipeline = GStreamerPipeline(cameraName: config.name, port: Int32(config.port))
        pipeline.delegate = delegate
        pipeline.setVideoView(videoView)
        
        pipelines[key] = pipeline
        
        print("Created GStreamer pipeline for \(config.name)")
        return true
    }
    
    func startStream(for cameraName: String) -> Bool {
        guard let pipeline = pipelines[cameraName] else {
            print("No pipeline found for \(cameraName)")
            return false
        }
        
        return pipeline.start()
    }
    
    func stopStream(for cameraName: String) {
        guard let pipeline = pipelines[cameraName] else {
            print("No pipeline found for \(cameraName)")
            return
        }
        
        pipeline.stop()
    }
    
    func pauseStream(for cameraName: String) {
        guard let pipeline = pipelines[cameraName] else {
            print("No pipeline found for \(cameraName)")
            return
        }
        
        pipeline.pause()
    }
    
    func isStreamPlaying(for cameraName: String) -> Bool {
        guard let pipeline = pipelines[cameraName] else {
            return false
        }
        
        return pipeline.isPlaying
    }
    
    func stopAllStreams() {
        for (_, pipeline) in pipelines {
            pipeline.stop()
        }
        pipelines.removeAll()
    }
}
