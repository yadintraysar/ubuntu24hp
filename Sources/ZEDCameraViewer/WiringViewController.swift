import AppKit
import Foundation

final class WiringViewController: NSViewController {
    private var backgroundView: NSView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    
    // Connection components
    private var routerIcon: NSView!
    private var serverIcon: NSView!
    private var remoteIcon: NSView!
    private var brokk70Icon: NSView!
    private var jetsonIcon: NSView!
    private var jetsonIcon2: NSView! // Second Jetson for fiber chain
    private var fiberAIcon: NSView!
    private var fiberBIcon: NSView!
    private var routerIcon2: NSView! // Second Router for fiber chain
    
    // Connection lines and checkmarks
    private var routerServerLine: NSView!
    private var serverRemoteLine: NSView!
    private var brokk70JetsonLine: NSView!
    private var jetsonFiberALine: NSView!
    private var fiberAFiberBLine: NSView!
    private var fiberBRouterLine: NSView!
    
    private var routerServerCheck: NSButton!
    private var serverRemoteCheck: NSButton!
    private var brokk70JetsonCheck: NSButton!
    private var jetsonFiberACheck: NSButton!
    private var fiberAFiberBCheck: NSButton!
    private var fiberBRouterCheck: NSButton!
    
    // Connection labels
    private var pacmanJetsonLabel: NSTextField!
    private var routerServerLabel: NSTextField!
    private var serverRemoteLabel: NSTextField!
    private var jetsonFiberALabel: NSTextField!
    private var fiberAFiberBLabel: NSTextField!
    private var fiberBRouterLabel: NSTextField!
    
    // Connection states
    private var connectionStates: [ConnectionState] = []
    private var currentConnection = 0
    private let totalConnections = 6
    

    
    enum ConnectionState {
        case pending
        case confirmed
    }
    
    override func loadView() {
        view = NSView()
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize connection states
        connectionStates = Array(repeating: .pending, count: totalConnections)
        startWiringCheck()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        
        // Dark gradient background (black/greys)
        backgroundView = NSView()
        backgroundView.wantsLayer = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            NSColor(white: 0.05, alpha: 1.0).cgColor,
            NSColor(white: 0.01, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        backgroundView.layer = gradientLayer
        
        // Main container
        let mainContainer = NSView()
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainContainer)
        
        // Title
        titleLabel = NSTextField(labelWithString: "WIRING")
        titleLabel.font = NSFont(name: "SF Pro Display", size: 48) ?? NSFont.boldSystemFont(ofSize: 48)
        titleLabel.textColor = NSColor.white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Subtitle
        subtitleLabel = NSTextField(labelWithString: "VERIFY SYSTEM CONNECTIONS")
        subtitleLabel.font = NSFont(name: "SF Mono", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Connection diagram container
        let diagramContainer = NSView()
        diagramContainer.translatesAutoresizingMaskIntoConstraints = false
        diagramContainer.wantsLayer = true
        diagramContainer.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.9).cgColor
        diagramContainer.layer?.cornerRadius = 16
        diagramContainer.layer?.borderWidth = 1
        diagramContainer.layer?.borderColor = NSColor(white: 0.3, alpha: 0.3).cgColor
        
        setupConnectionDiagram(in: diagramContainer)
        
        // Layout
        mainContainer.addSubview(titleLabel)
        mainContainer.addSubview(subtitleLabel)
        mainContainer.addSubview(diagramContainer)
        
        NSLayoutConstraint.activate([
            // Background
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Main container
            mainContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mainContainer.widthAnchor.constraint(equalToConstant: 1000),
            mainContainer.heightAnchor.constraint(equalToConstant: 700),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: mainContainer.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            
            // Diagram container
            diagramContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            diagramContainer.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            diagramContainer.widthAnchor.constraint(equalToConstant: 900),
            diagramContainer.heightAnchor.constraint(equalToConstant: 500),
            diagramContainer.bottomAnchor.constraint(lessThanOrEqualTo: mainContainer.bottomAnchor, constant: -40)
        ])
    }
    
    private func setupConnectionDiagram(in container: NSView) {
        // Create component icons with real images
        
        // Top row: Router -> Server -> Remote
        routerIcon = createComponentIcon(title: "ROUTER", imageName: "router.png")
        serverIcon = createComponentIcon(title: "SERVER", imageName: "server.png")
        remoteIcon = createComponentIcon(title: "REMOTE", imageName: "remote.png")
        
        // First row: PACMAN -> Jetson (pyramid structure - start with 2-step process)
        brokk70Icon = createComponentIcon(title: "PACMAN", imageName: "brokk.png")
        jetsonIcon = createComponentIcon(title: "JETSON", imageName: "neousys1.png")
        
        // Bottom row: Jetson -> Fiber A -> Fiber B -> Router (fiber optic chain)
        jetsonIcon2 = createComponentIcon(title: "JETSON", imageName: "neousys1.png")
        fiberAIcon = createComponentIcon(title: "FIBER A", imageName: "fiber.png")
        fiberBIcon = createComponentIcon(title: "FIBER B", imageName: "fiber.png")
        routerIcon2 = createComponentIcon(title: "ROUTER", imageName: "router.png")
        
        // Connection lines
        routerServerLine = createConnectionLine()
        serverRemoteLine = createConnectionLine()
        brokk70JetsonLine = createConnectionLine()
        jetsonFiberALine = createConnectionLine()
        fiberAFiberBLine = createConnectionLine()
        fiberBRouterLine = createConnectionLine()
        
        // Connection labels with specific cable types
        pacmanJetsonLabel = createConnectionLabel(text: "M12/CAN BUS (MALE)")
        routerServerLabel = createConnectionLabel(text: "ETHERNET")
        serverRemoteLabel = createConnectionLabel(text: "CAN BUS (FEMALE)")
        jetsonFiberALabel = createConnectionLabel(text: "ETHERNET")
        fiberAFiberBLabel = createConnectionLabel(text: "FIBER CABLE")
        fiberBRouterLabel = createConnectionLabel(text: "ETHERNET")
        
        // Checkmark buttons (reordered for pyramid structure)
        brokk70JetsonCheck = createCheckButton(tag: 0, action: #selector(connectionConfirmed(_:))) // Row 1: PACMAN -> Jetson
        routerServerCheck = createCheckButton(tag: 1, action: #selector(connectionConfirmed(_:)))   // Row 2: Router -> Server
        serverRemoteCheck = createCheckButton(tag: 2, action: #selector(connectionConfirmed(_:)))   // Row 2: Server -> Remote
        jetsonFiberACheck = createCheckButton(tag: 3, action: #selector(connectionConfirmed(_:)))   // Row 3: Jetson -> Fiber A
        fiberAFiberBCheck = createCheckButton(tag: 4, action: #selector(connectionConfirmed(_:)))   // Row 3: Fiber A -> Fiber B
        fiberBRouterCheck = createCheckButton(tag: 5, action: #selector(connectionConfirmed(_:)))   // Row 3: Fiber B -> Router
        
        // Add all elements to container
        container.addSubview(routerIcon)
        container.addSubview(serverIcon)
        container.addSubview(remoteIcon)
        container.addSubview(brokk70Icon)
        container.addSubview(jetsonIcon)
        container.addSubview(jetsonIcon2)
        container.addSubview(fiberAIcon)
        container.addSubview(fiberBIcon)
        container.addSubview(routerIcon2)
        
        container.addSubview(routerServerLine)
        container.addSubview(serverRemoteLine)
        container.addSubview(brokk70JetsonLine)
        container.addSubview(jetsonFiberALine)
        container.addSubview(fiberAFiberBLine)
        container.addSubview(fiberBRouterLine)
        
        container.addSubview(pacmanJetsonLabel)
        container.addSubview(routerServerLabel)
        container.addSubview(serverRemoteLabel)
        container.addSubview(jetsonFiberALabel)
        container.addSubview(fiberAFiberBLabel)
        container.addSubview(fiberBRouterLabel)
        
        container.addSubview(routerServerCheck)
        container.addSubview(serverRemoteCheck)
        container.addSubview(brokk70JetsonCheck)
        container.addSubview(jetsonFiberACheck)
        container.addSubview(fiberAFiberBCheck)
        container.addSubview(fiberBRouterCheck)
        
        // Layout constraints - Pyramid structure
        NSLayoutConstraint.activate([
            // Row 1: PACMAN -> Jetson (2 items - top of pyramid, nudged for better centering)
            brokk70Icon.leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: -260),
            brokk70Icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 60),
            
            jetsonIcon.leadingAnchor.constraint(equalTo: brokk70Icon.trailingAnchor, constant: 120),
            jetsonIcon.centerYAnchor.constraint(equalTo: brokk70Icon.centerYAnchor),
            
            // Row 2: Router -> Server -> Remote (3 items - middle of pyramid)
            routerIcon.leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: -320),
            routerIcon.topAnchor.constraint(equalTo: brokk70Icon.bottomAnchor, constant: 90),
            
            serverIcon.leadingAnchor.constraint(equalTo: routerIcon.trailingAnchor, constant: 120),
            serverIcon.centerYAnchor.constraint(equalTo: routerIcon.centerYAnchor),
            
            remoteIcon.leadingAnchor.constraint(equalTo: serverIcon.trailingAnchor, constant: 120),
            remoteIcon.centerYAnchor.constraint(equalTo: serverIcon.centerYAnchor),
            
            // Row 3: Jetson -> Fiber A -> Fiber B -> Router (4 items - bottom of pyramid)
            jetsonIcon2.leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: -380),
            jetsonIcon2.topAnchor.constraint(equalTo: routerIcon.bottomAnchor, constant: 90),
            
            fiberAIcon.leadingAnchor.constraint(equalTo: jetsonIcon2.trailingAnchor, constant: 120),
            fiberAIcon.centerYAnchor.constraint(equalTo: jetsonIcon2.centerYAnchor),
            
            fiberBIcon.leadingAnchor.constraint(equalTo: fiberAIcon.trailingAnchor, constant: 120),
            fiberBIcon.centerYAnchor.constraint(equalTo: fiberAIcon.centerYAnchor),
            
            routerIcon2.leadingAnchor.constraint(equalTo: fiberBIcon.trailingAnchor, constant: 120),
            routerIcon2.centerYAnchor.constraint(equalTo: fiberBIcon.centerYAnchor),
            
            // Connection lines
            // Row 1: PACMAN -> Jetson
            brokk70JetsonLine.leadingAnchor.constraint(equalTo: brokk70Icon.trailingAnchor, constant: 10),
            brokk70JetsonLine.trailingAnchor.constraint(equalTo: jetsonIcon.leadingAnchor, constant: -10),
            brokk70JetsonLine.centerYAnchor.constraint(equalTo: brokk70Icon.centerYAnchor),
            brokk70JetsonLine.heightAnchor.constraint(equalToConstant: 2),
            
            // Row 2: Router -> Server -> Remote
            routerServerLine.leadingAnchor.constraint(equalTo: routerIcon.trailingAnchor, constant: 10),
            routerServerLine.trailingAnchor.constraint(equalTo: serverIcon.leadingAnchor, constant: -10),
            routerServerLine.centerYAnchor.constraint(equalTo: routerIcon.centerYAnchor),
            routerServerLine.heightAnchor.constraint(equalToConstant: 2),
            
            serverRemoteLine.leadingAnchor.constraint(equalTo: serverIcon.trailingAnchor, constant: 10),
            serverRemoteLine.trailingAnchor.constraint(equalTo: remoteIcon.leadingAnchor, constant: -10),
            serverRemoteLine.centerYAnchor.constraint(equalTo: serverIcon.centerYAnchor),
            serverRemoteLine.heightAnchor.constraint(equalToConstant: 2),
            
            // Row 3: Fiber optic chain lines
            jetsonFiberALine.leadingAnchor.constraint(equalTo: jetsonIcon2.trailingAnchor, constant: 10),
            jetsonFiberALine.trailingAnchor.constraint(equalTo: fiberAIcon.leadingAnchor, constant: -10),
            jetsonFiberALine.centerYAnchor.constraint(equalTo: jetsonIcon2.centerYAnchor),
            jetsonFiberALine.heightAnchor.constraint(equalToConstant: 2),
            
            fiberAFiberBLine.leadingAnchor.constraint(equalTo: fiberAIcon.trailingAnchor, constant: 10),
            fiberAFiberBLine.trailingAnchor.constraint(equalTo: fiberBIcon.leadingAnchor, constant: -10),
            fiberAFiberBLine.centerYAnchor.constraint(equalTo: fiberAIcon.centerYAnchor),
            fiberAFiberBLine.heightAnchor.constraint(equalToConstant: 2),
            
            fiberBRouterLine.leadingAnchor.constraint(equalTo: fiberBIcon.trailingAnchor, constant: 10),
            fiberBRouterLine.trailingAnchor.constraint(equalTo: routerIcon2.leadingAnchor, constant: -10),
            fiberBRouterLine.centerYAnchor.constraint(equalTo: fiberBIcon.centerYAnchor),
            fiberBRouterLine.heightAnchor.constraint(equalToConstant: 2),
            
            // Connection labels (positioned above each connection line)
            // Row 1: PACMAN -> Jetson
            pacmanJetsonLabel.centerXAnchor.constraint(equalTo: brokk70JetsonLine.centerXAnchor),
            pacmanJetsonLabel.bottomAnchor.constraint(equalTo: brokk70JetsonLine.topAnchor, constant: -15),
            
            // Row 2: Router -> Server -> Remote
            routerServerLabel.centerXAnchor.constraint(equalTo: routerServerLine.centerXAnchor),
            routerServerLabel.bottomAnchor.constraint(equalTo: routerServerLine.topAnchor, constant: -15),
            
            serverRemoteLabel.centerXAnchor.constraint(equalTo: serverRemoteLine.centerXAnchor),
            serverRemoteLabel.bottomAnchor.constraint(equalTo: serverRemoteLine.topAnchor, constant: -15),
            
            // Row 3: Fiber chain
            jetsonFiberALabel.centerXAnchor.constraint(equalTo: jetsonFiberALine.centerXAnchor),
            jetsonFiberALabel.bottomAnchor.constraint(equalTo: jetsonFiberALine.topAnchor, constant: -15),
            
            fiberAFiberBLabel.centerXAnchor.constraint(equalTo: fiberAFiberBLine.centerXAnchor),
            fiberAFiberBLabel.bottomAnchor.constraint(equalTo: fiberAFiberBLine.topAnchor, constant: -15),
            
            fiberBRouterLabel.centerXAnchor.constraint(equalTo: fiberBRouterLine.centerXAnchor),
            fiberBRouterLabel.bottomAnchor.constraint(equalTo: fiberBRouterLine.topAnchor, constant: -15),
            
            // Checkmark buttons (positioned on the connection lines)
            routerServerCheck.centerXAnchor.constraint(equalTo: routerServerLine.centerXAnchor),
            routerServerCheck.centerYAnchor.constraint(equalTo: routerServerLine.centerYAnchor),
            
            serverRemoteCheck.centerXAnchor.constraint(equalTo: serverRemoteLine.centerXAnchor),
            serverRemoteCheck.centerYAnchor.constraint(equalTo: serverRemoteLine.centerYAnchor),
            
            brokk70JetsonCheck.centerXAnchor.constraint(equalTo: brokk70JetsonLine.centerXAnchor),
            brokk70JetsonCheck.centerYAnchor.constraint(equalTo: brokk70JetsonLine.centerYAnchor),
            
            jetsonFiberACheck.centerXAnchor.constraint(equalTo: jetsonFiberALine.centerXAnchor),
            jetsonFiberACheck.centerYAnchor.constraint(equalTo: jetsonFiberALine.centerYAnchor),
            
            fiberAFiberBCheck.centerXAnchor.constraint(equalTo: fiberAFiberBLine.centerXAnchor),
            fiberAFiberBCheck.centerYAnchor.constraint(equalTo: fiberAFiberBLine.centerYAnchor),
            
            fiberBRouterCheck.centerXAnchor.constraint(equalTo: fiberBRouterLine.centerXAnchor),
            fiberBRouterCheck.centerYAnchor.constraint(equalTo: fiberBRouterLine.centerYAnchor)
        ])
    }
    
    private func createComponentIcon(title: String, imageName: String? = nil, color: NSColor? = nil) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        
        // Icon view (either image or placeholder)
        if let imageName = imageName {
            // Use real image
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown
            
            // Load image from bundle
            if let image = loadImageFromBundle(named: imageName) {
                imageView.image = image
            }
            
            container.addSubview(imageView)
            
            // Label
            let label = NSTextField(labelWithString: title)
            label.font = NSFont(name: "SF Mono", size: 10) ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
            label.textColor = NSColor.white
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            
            NSLayoutConstraint.activate([
                // Image
                imageView.topAnchor.constraint(equalTo: container.topAnchor),
                imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 80),
                imageView.heightAnchor.constraint(equalToConstant: 60),
                
                // Label
                label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                
                // Container size
                container.widthAnchor.constraint(equalToConstant: 100),
                container.heightAnchor.constraint(equalToConstant: 80)
            ])
            
        } else if let color = color {
            // Use placeholder colored rectangle
            let iconView = NSView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.wantsLayer = true
            iconView.layer?.backgroundColor = color.cgColor
            iconView.layer?.cornerRadius = 8
            
            container.addSubview(iconView)
            
            // Label
            let label = NSTextField(labelWithString: title)
            label.font = NSFont(name: "SF Mono", size: 10) ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
            label.textColor = NSColor.white
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            
            NSLayoutConstraint.activate([
                // Icon
                iconView.topAnchor.constraint(equalTo: container.topAnchor),
                iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 80),
                iconView.heightAnchor.constraint(equalToConstant: 60),
                
                // Label
                label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                
                // Container size
                container.widthAnchor.constraint(equalToConstant: 100),
                container.heightAnchor.constraint(equalToConstant: 80)
            ])
        }
        
        return container
    }
    
    private func loadImageFromBundle(named imageName: String) -> NSImage? {
        // Try multiple approaches to load the image
        
        // Try Bundle.module first (for SPM resources)
        if let bundleURL = Bundle.module.url(forResource: imageName.replacingOccurrences(of: ".png", with: ""), withExtension: "png"),
           let image = NSImage(contentsOf: bundleURL) {
            return image
        }
        
        // Try Bundle.main as fallback
        if let image = NSImage(named: imageName.replacingOccurrences(of: ".png", with: "")) {
            return image
        }
        
        // Try direct file path
        let directPath = "/Users/yadinsoffer/Desktop/Twelve/Sources/ZEDCameraViewer/\(imageName)"
        if let image = NSImage(contentsOfFile: directPath) {
            return image
        }
        
        print("Could not load image: \(imageName)")
        return nil
    }
    
    private func createConnectionLine() -> NSView {
        let line = NSView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(white: 0.4, alpha: 0.6).cgColor
        return line
    }
    
    private func createConnectionLabel(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont(name: "SF Mono", size: 9) ?? NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        label.textColor = NSColor(white: 0.6, alpha: 1.0)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func createCheckButton(tag: Int, action: Selector) -> NSButton {
        let button = NSButton()
        button.title = "✓"
        button.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = 15
        button.layer?.borderWidth = 2
        button.layer?.borderColor = NSColor(white: 0.4, alpha: 0.6).cgColor
        button.contentTintColor = NSColor(white: 0.4, alpha: 0.6)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.tag = tag
        button.target = self
        button.action = action
        return button
    }
    
    private func createFuturisticButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.wantsLayer = true
        
        // Futuristic styling (white/grey theme)
        button.layer?.backgroundColor = NSColor(white: 0.2, alpha: 0.8).cgColor
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor(white: 0.6, alpha: 0.8).cgColor
        
        button.contentTintColor = NSColor.white
        button.font = NSFont(name: "SF Mono", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
        
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.widthAnchor.constraint(equalToConstant: 280).isActive = true
        
        return button
    }
    
    private func startWiringCheck() {
        updateConnectionStates()
        highlightCurrentConnection()
    }
    
    private func updateConnectionStates() {
        let checkButtons = [brokk70JetsonCheck, routerServerCheck, serverRemoteCheck,
                           jetsonFiberACheck, fiberAFiberBCheck, fiberBRouterCheck]
        let connectionLines = [brokk70JetsonLine, routerServerLine, serverRemoteLine,
                              jetsonFiberALine, fiberAFiberBLine, fiberBRouterLine]
        
        for i in 0..<totalConnections {
            let button = checkButtons[i]!
            let line = connectionLines[i]!
            let state = connectionStates[i]
            
            switch state {
            case .pending:
                button.layer?.borderColor = NSColor(white: 0.4, alpha: 0.6).cgColor
                button.layer?.backgroundColor = NSColor.clear.cgColor
                button.contentTintColor = NSColor(white: 0.4, alpha: 0.6)
                line.layer?.backgroundColor = NSColor(white: 0.4, alpha: 0.6).cgColor
                
            case .confirmed:
                button.layer?.borderColor = NSColor.white.cgColor
                button.layer?.backgroundColor = NSColor.white.cgColor
                button.contentTintColor = NSColor.black
                line.layer?.backgroundColor = NSColor.white.cgColor
            }
        }
        
        // Check if all connections are confirmed
        let allConfirmed = connectionStates.allSatisfy { $0 == .confirmed }
        if allConfirmed {
            subtitleLabel.stringValue = "ALL CONNECTIONS VERIFIED - PROCEEDING TO MAIN APP"
            
            // Auto-continue to main app after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.proceedToMainApp()
            }
        }
    }
    
    private func highlightCurrentConnection() {
        // Add pulsing animation to pending connections
        let checkButtons = [brokk70JetsonCheck, routerServerCheck, serverRemoteCheck,
                           jetsonFiberACheck, fiberAFiberBCheck, fiberBRouterCheck]
        
        for i in 0..<totalConnections {
            let button = checkButtons[i]!
            
            if connectionStates[i] == .pending {
                let pulseAnimation = CABasicAnimation(keyPath: "opacity")
                pulseAnimation.fromValue = 0.5
                pulseAnimation.toValue = 1.0
                pulseAnimation.duration = 1.0
                pulseAnimation.repeatCount = .infinity
                pulseAnimation.autoreverses = true
                button.layer?.add(pulseAnimation, forKey: "pulse")
            } else {
                button.layer?.removeAnimation(forKey: "pulse")
            }
        }
    }
    
    @objc private func connectionConfirmed(_ sender: NSButton) {
        let connectionIndex = sender.tag
        
        // Mark connection as confirmed
        connectionStates[connectionIndex] = .confirmed
        
        // Update UI
        updateConnectionStates()
        highlightCurrentConnection()
        
        // Button feedback animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            sender.animator().alphaValue = 0.6
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                sender.animator().alphaValue = 1.0
            }
        }
    }
    
    private func proceedToMainApp() {
        let micCheckVC = MicCheckViewController()
        
        // Preserve window size during transition
        let currentFrame = self.view.window?.frame
        
        // Smooth transition
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            self.view.animator().alphaValue = 0.0
        } completionHandler: {
            self.view.window?.contentViewController = micCheckVC
            
            // Restore window size after transition
            if let frame = currentFrame {
                self.view.window?.setFrame(frame, display: true, animate: false)
            }
        }
    }
}
