import AppKit
import Foundation
import Cocoa
import GStreamerBridge

protocol CameraStreamViewDelegate: AnyObject {
    func cameraStreamViewWasClicked(_ cameraStreamView: CameraStreamView)
}

class CameraStreamView: NSView, GStreamerPipelineDelegate {
    weak var delegate: CameraStreamViewDelegate?
    private let config: CameraConfig
    private var pipeline: GStreamerPipeline?
    private var isStreaming = false
    private var embeddedWindow: NSWindow?
    private var windowSearchTimer: Timer?
    private var captureTimer: Timer?
    private var videoAspectConstraint: NSLayoutConstraint?
    
    // UI Elements
    private var titleLabel: NSTextField!
    private var statusLabel: NSTextField!
    private var videoPlaceholder: NSView!
    private var toggleButton: NSButton!
    
    init(config: CameraConfig) {
        self.config = config
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Title label
        titleLabel = NSTextField(labelWithString: config.name)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "Port \(config.port) • Stopped")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)
        
        // Video placeholder
        videoPlaceholder = NSView()
        videoPlaceholder.wantsLayer = true
        videoPlaceholder.layer?.backgroundColor = NSColor.black.cgColor
        videoPlaceholder.layer?.cornerRadius = 4
        videoPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(videoPlaceholder)
        
        // Add placeholder text
        let placeholderLabel = NSTextField(labelWithString: "Video Stream")
        placeholderLabel.font = NSFont.systemFont(ofSize: 16)
        placeholderLabel.textColor = .tertiaryLabelColor
        placeholderLabel.alignment = .center
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        videoPlaceholder.addSubview(placeholderLabel)
        
        // Toggle button as compact icon at top-right
        toggleButton = NSButton(image: NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil) ?? NSImage(), target: self, action: #selector(toggleStream))
        toggleButton.bezelStyle = .texturedRounded
        toggleButton.isBordered = false
        toggleButton.contentTintColor = .labelColor
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toggleButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            videoPlaceholder.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            videoPlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            videoPlaceholder.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            videoPlaceholder.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            placeholderLabel.centerXAnchor.constraint(equalTo: videoPlaceholder.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: videoPlaceholder.centerYAnchor),
            
            toggleButton.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            toggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            toggleButton.widthAnchor.constraint(equalToConstant: 20),
            toggleButton.heightAnchor.constraint(equalToConstant: 20)
        ])

        // Prefer 16:9 but allow window growth by using high-but-not-required priority
        videoAspectConstraint = videoPlaceholder.heightAnchor.constraint(equalTo: videoPlaceholder.widthAnchor, multiplier: 9.0/16.0)
        videoAspectConstraint?.priority = .defaultLow
        videoAspectConstraint?.isActive = true
        
        // Add click gesture recognizer only to the video area (not the header controls)
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        videoPlaceholder.addGestureRecognizer(clickGesture)
    }
    
    func startStream() {
        guard !isStreaming else { return }
        
        print("🎬 Starting in-process GStreamer stream for \(config.name)")
        GStreamerPipeline.initializeGStreamer()
        let useAlt = (config.id == 0)
        let p: GStreamerPipeline
        if useAlt {
            p = GStreamerPipeline(cameraName: config.name, port: Int32(config.port), useAlternateSoftwareH264: true)
        } else {
            p = GStreamerPipeline(cameraName: config.name, port: Int32(config.port))
        }
        p.delegate = self
        p.setVideoView(videoPlaceholder)
        if p.start() {
            self.pipeline = p
            self.isStreaming = true
            self.updateUI()
        } else {
            showError("Failed to start pipeline for \(config.name)")
        }
    }
    
    func stopStream() {
        guard isStreaming else { return }
        print("🛑 Stopping stream for \(config.name)")
        pipeline?.stop()
        pipeline = nil
        isStreaming = false
        
        updateUI()
    }
    
    @objc func toggleStream() {
        if isStreaming {
            stopStream()
        } else {
            startStream()
        }
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            if self.isStreaming {
                self.statusLabel.stringValue = "Port \(self.config.port) • Streaming"
                self.statusLabel.textColor = .systemGreen
                self.toggleButton.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
                self.videoPlaceholder.layer?.backgroundColor = NSColor.black.cgColor
            } else {
                self.statusLabel.stringValue = "Port \(self.config.port) • Stopped"
                self.statusLabel.textColor = .secondaryLabelColor
                self.toggleButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
                self.videoPlaceholder.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            }
        }
    }
    
    // In-process rendering; no external screen/window logic needed
    
    private func showStreamPlaceholder() {
        // Clear existing content
        videoPlaceholder.subviews.forEach { $0.removeFromSuperview() }
        
        // Create a "streaming" indicator
        let streamingLabel = NSTextField(labelWithString: "🎥 STREAMING")
        streamingLabel.font = NSFont.boldSystemFont(ofSize: 18)
        streamingLabel.textColor = .systemGreen
        streamingLabel.alignment = .center
        streamingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let portLabel = NSTextField(labelWithString: "Port \(config.port)")
        portLabel.font = NSFont.systemFont(ofSize: 12)
        portLabel.textColor = .secondaryLabelColor
        portLabel.alignment = .center
        portLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let infoLabel = NSTextField(labelWithString: "Video window opened\nCheck for separate video window")
        infoLabel.font = NSFont.systemFont(ofSize: 10)
        infoLabel.textColor = .tertiaryLabelColor
        infoLabel.alignment = .center
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        videoPlaceholder.addSubview(streamingLabel)
        videoPlaceholder.addSubview(portLabel)
        videoPlaceholder.addSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            streamingLabel.centerXAnchor.constraint(equalTo: videoPlaceholder.centerXAnchor),
            streamingLabel.centerYAnchor.constraint(equalTo: videoPlaceholder.centerYAnchor, constant: -20),
            
            portLabel.centerXAnchor.constraint(equalTo: videoPlaceholder.centerXAnchor),
            portLabel.topAnchor.constraint(equalTo: streamingLabel.bottomAnchor, constant: 8),
            
            infoLabel.centerXAnchor.constraint(equalTo: videoPlaceholder.centerXAnchor),
            infoLabel.topAnchor.constraint(equalTo: portLabel.bottomAnchor, constant: 8)
        ])
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Camera Stream Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        delegate?.cameraStreamViewWasClicked(self)
    }
    
    var cameraConfig: CameraConfig {
        return config
    }
    
    // Removed window-embedding and AppleScript positioning; in-process overlay draws directly into videoPlaceholder.
}
