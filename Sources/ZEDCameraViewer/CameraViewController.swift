import AppKit
import Foundation

class CameraViewController: NSViewController, CameraStreamViewDelegate {
    private var stackView: NSStackView!
    private var videoContainer: NSView!
    private var primaryContainer: NSView!
    private var thumbnailsContainer: NSView!
    private var statsView: StatsSidebarView!
    
    // Camera stream views
    private var cameraViews: [CameraStreamView] = []
    private var currentPrimaryIndex = 0
    
    // Stream configuration
    private let cameraConfigs = [
        CameraConfig(id: 0, name: "Camera 0: Overhead Camera", port: 5001),
        CameraConfig(id: 1, name: "Camera 1: Boom Camera", port: 5002),
        CameraConfig(id: 2, name: "Camera 2: Front Camera", port: 5004),
        CameraConfig(id: 3, name: "Camera 3: Back Camera", port: 5003)
    ]
    
    // Control buttons (removed global start/stop for cleaner UI)
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraViews()
    }
    
    private func setupUI() {
        // Setup video container pinned to full width/height
        setupVideoContainer()
        view.addSubview(videoContainer)
        NSLayoutConstraint.activate([
            videoContainer.topAnchor.constraint(equalTo: view.topAnchor),
            videoContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

    }
    
    private func setupVideoContainer() {
        videoContainer = NSView()
        videoContainer.translatesAutoresizingMaskIntoConstraints = false
        // Transparent background to maximize visual space
        videoContainer.wantsLayer = false
    }
    
    private func setupCameraViews() {
        // Main + thumbnails layout
        primaryContainer = NSView()
        primaryContainer.translatesAutoresizingMaskIntoConstraints = false
        primaryContainer.setContentHuggingPriority(.defaultLow, for: .vertical)
        primaryContainer.setContentCompressionResistancePriority(.required, for: .vertical)
        thumbnailsContainer = NSView()
        thumbnailsContainer.translatesAutoresizingMaskIntoConstraints = false
        thumbnailsContainer.setContentHuggingPriority(.required, for: .vertical)
        thumbnailsContainer.setContentCompressionResistancePriority(.required, for: .vertical)
        
        // Left column: primary above thumbnails in a vertical stack
        let leftColumn = NSStackView()
        leftColumn.orientation = .vertical
        leftColumn.spacing = 8
        leftColumn.distribution = .fill
        leftColumn.alignment = .leading
        leftColumn.translatesAutoresizingMaskIntoConstraints = false
        // Favor taking available horizontal space
        leftColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        leftColumn.setContentCompressionResistancePriority(.required, for: .horizontal)
        leftColumn.addArrangedSubview(primaryContainer)
        leftColumn.addArrangedSubview(thumbnailsContainer)
        // Force arranged subviews to stretch full width of the left column
        NSLayoutConstraint.activate([
            primaryContainer.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor),
            primaryContainer.trailingAnchor.constraint(equalTo: leftColumn.trailingAnchor),
            thumbnailsContainer.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor),
            thumbnailsContainer.trailingAnchor.constraint(equalTo: leftColumn.trailingAnchor)
        ])
        
        // Constrain thumbnails height within the left column (slightly smaller to grow main)
        thumbnailsContainer.heightAnchor.constraint(equalToConstant: 200).isActive = true
        // Ensure primary area has a reasonable minimum height
        primaryContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 420).isActive = true
        
        // Main row: left column + sidebar
        let mainRow = NSStackView()
        mainRow.orientation = .horizontal
        mainRow.spacing = 8
        mainRow.distribution = .fill
        mainRow.alignment = .top
        mainRow.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.addSubview(mainRow)
        
        // Stats sidebar (right)
        statsView = StatsSidebarView()
        // Slightly reduce fixed width to give more room to the main area
        statsView.widthAnchor.constraint(equalToConstant: 440).isActive = true
        statsView.setContentHuggingPriority(.required, for: .horizontal)
        statsView.setContentCompressionResistancePriority(.required, for: .horizontal)
        statsView.setContentHuggingPriority(.defaultLow, for: .vertical)
        statsView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        mainRow.addArrangedSubview(leftColumn)
        mainRow.addArrangedSubview(statsView)
        
        // Pin the main row to full height; sidebar will span full height
        NSLayoutConstraint.activate([
            mainRow.topAnchor.constraint(equalTo: videoContainer.safeAreaLayoutGuide.topAnchor, constant: 8),
            mainRow.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor),
            mainRow.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor),
            mainRow.bottomAnchor.constraint(equalTo: videoContainer.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
        
        // Create camera views
        for config in cameraConfigs {
            let cameraView = CameraStreamView(config: config)
            cameraView.delegate = self
            cameraViews.append(cameraView)
        }
        
        guard !cameraViews.isEmpty else { return }
        
        // Add primary view (first camera)
        let primaryView = cameraViews[0]
        primaryContainer.addSubview(primaryView)
        NSLayoutConstraint.activate([
            primaryView.topAnchor.constraint(equalTo: primaryContainer.topAnchor),
            primaryView.leadingAnchor.constraint(equalTo: primaryContainer.leadingAnchor),
            primaryView.trailingAnchor.constraint(equalTo: primaryContainer.trailingAnchor),
            primaryView.bottomAnchor.constraint(equalTo: primaryContainer.bottomAnchor)
        ])
        
        // Thumbnails (remaining cameras) in a horizontal stack
        let thumbsStack = NSStackView()
        thumbsStack.orientation = .horizontal
        thumbsStack.spacing = 12
        thumbsStack.alignment = .centerY
        thumbsStack.distribution = .fillEqually
        thumbsStack.translatesAutoresizingMaskIntoConstraints = false
        thumbnailsContainer.addSubview(thumbsStack)
        NSLayoutConstraint.activate([
            thumbsStack.topAnchor.constraint(equalTo: thumbnailsContainer.topAnchor, constant: 8),
            thumbsStack.leadingAnchor.constraint(equalTo: thumbnailsContainer.leadingAnchor, constant: 0),
            thumbsStack.trailingAnchor.constraint(equalTo: thumbnailsContainer.trailingAnchor, constant: 0),
            thumbsStack.bottomAnchor.constraint(equalTo: thumbnailsContainer.bottomAnchor, constant: -8)
        ])
        
        if cameraViews.count > 1 {
            for i in 1..<cameraViews.count {
                thumbsStack.addArrangedSubview(cameraViews[i])
            }
        }
    }
    
    @objc func startAllStreams() {
        for cameraView in cameraViews {
            cameraView.startStream()
        }
    }
    
    @objc func stopAllStreams() {
        for cameraView in cameraViews {
            cameraView.stopStream()
        }
    }
    
    func toggleCamera(_ cameraId: Int) {
        guard cameraId < cameraViews.count else { return }
        cameraViews[cameraId].toggleStream()
    }
    
    func refreshWebView() {
        statsView?.refreshWebContent()
    }

    
    
    // MARK: - CameraStreamViewDelegate
    
    func cameraStreamViewWasClicked(_ cameraStreamView: CameraStreamView) {
        let clickedIndex = cameraViews.firstIndex(of: cameraStreamView)
        guard let clickedIndex = clickedIndex, clickedIndex != currentPrimaryIndex else {
            return // Don't swap if clicking the current primary view
        }
        
        swapViews(newPrimaryIndex: clickedIndex)
    }
    
    private func swapViews(newPrimaryIndex: Int) {
        guard newPrimaryIndex < cameraViews.count, newPrimaryIndex != currentPrimaryIndex else {
            return
        }
        
        let oldPrimaryView = cameraViews[currentPrimaryIndex]
        let newPrimaryView = cameraViews[newPrimaryIndex]
        
        // Remove both views from their current containers
        oldPrimaryView.removeFromSuperview()
        newPrimaryView.removeFromSuperview()
        
        // Add new primary view to primary container
        primaryContainer.addSubview(newPrimaryView)
        NSLayoutConstraint.activate([
            newPrimaryView.topAnchor.constraint(equalTo: primaryContainer.topAnchor),
            newPrimaryView.leadingAnchor.constraint(equalTo: primaryContainer.leadingAnchor),
            newPrimaryView.trailingAnchor.constraint(equalTo: primaryContainer.trailingAnchor),
            newPrimaryView.bottomAnchor.constraint(equalTo: primaryContainer.bottomAnchor)
        ])
        
        // Rebuild thumbnail stack
        rebuildThumbnailStack(excludingIndex: newPrimaryIndex)
        
        // Update current primary index
        currentPrimaryIndex = newPrimaryIndex
    }
    
    private func rebuildThumbnailStack(excludingIndex: Int) {
        // Remove existing thumbnail stack
        thumbnailsContainer.subviews.forEach { $0.removeFromSuperview() }
        
        // Create new thumbnail stack
        let thumbsStack = NSStackView()
        thumbsStack.orientation = .horizontal
        thumbsStack.spacing = 12
        thumbsStack.alignment = .centerY
        thumbsStack.distribution = .fillEqually
        thumbsStack.translatesAutoresizingMaskIntoConstraints = false
        thumbnailsContainer.addSubview(thumbsStack)
        
        NSLayoutConstraint.activate([
            thumbsStack.topAnchor.constraint(equalTo: thumbnailsContainer.topAnchor, constant: 8),
            thumbsStack.leadingAnchor.constraint(equalTo: thumbnailsContainer.leadingAnchor, constant: 0),
            thumbsStack.trailingAnchor.constraint(equalTo: thumbnailsContainer.trailingAnchor, constant: 0),
            thumbsStack.bottomAnchor.constraint(equalTo: thumbnailsContainer.bottomAnchor, constant: -8)
        ])
        
        // Add all camera views except the primary one to thumbnails
        for (index, cameraView) in cameraViews.enumerated() {
            if index != excludingIndex {
                thumbsStack.addArrangedSubview(cameraView)
            }
        }
    }
}
