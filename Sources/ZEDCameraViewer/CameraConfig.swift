import Foundation

struct CameraConfig {
    let id: Int
    let name: String
    let port: Int
    let sourceIP: String
    
    init(id: Int, name: String, port: Int, sourceIP: String = "192.168.1.254") {
        self.id = id
        self.name = name
        self.port = port
        self.sourceIP = sourceIP
    }
    
    var gstreamerPipeline: String {
        return """
        udpsrc port=\(port) ! \
        application/x-rtp,clock-rate=90000,payload=96 ! \
        queue ! \
        rtph264depay ! \
        h264parse ! \
        avdec_h264 ! \
        queue ! \
        autovideoconvert ! \
        fpsdisplaysink text-overlay=false video-sink=osxvideosink name="\(name)"
        """
    }
}
