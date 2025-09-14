import AppKit
import SceneKit
import Foundation

final class SystemsCheckViewController: NSViewController {
    private var backgroundView: NSView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var sceneView: SCNView!
    private var progressContainer: NSView!
    private var progressLabels: [NSTextField] = []
    private var progressIndicators: [NSView] = []
    private var checkButtons: [NSButton] = []
    private var xButtons: [NSButton] = []
    private var stepStates: [StepState] = []
    
    enum StepState {
        case pending
        case confirmed
        case rejected
    }
    
    // 3D Scene components
    private var scene: SCNScene!
    private var cameraNode: SCNNode!
    private var pacmanNode: SCNNode!
    
    // Step tracking
    private var currentStep = 0
    private let totalSteps = 4
    private let stepTitles = [
        "FRONT CAMERA VERIFICATION",
        "BOOM CAMERA VERIFICATION", 
        "BACK CAMERA VERIFICATION",
        "OVERHEAD CAMERA VERIFICATION"
    ]
    
    // Camera positions and zoom levels for each verification step
    private let cameraSettings: [(position: SCNVector3, zoom: Float, description: String)] = [
        (position: SCNVector3(0, 0, 8), zoom: 1.0, description: "Front Camera - Frontal view of device"),
        (position: SCNVector3(2, 1, 4), zoom: 2.0, description: "Boom Camera - Diagonal view with 2x zoom"),
        (position: SCNVector3(0, 1, -8), zoom: 1.0, description: "Back Camera - Rear view of device"),
        (position: SCNVector3(0, 8, 0), zoom: 1.0, description: "Overhead Camera - View from above")
    ]
    
    override func loadView() {
        view = NSView()
        setupUI()
        setup3DScene()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize step states
        stepStates = Array(repeating: .pending, count: totalSteps)
        startSystemsCheck()
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
        
        // Create horizontal layout: Left panel + Right 3D view
        let horizontalContainer = NSStackView()
        horizontalContainer.orientation = .horizontal
        horizontalContainer.spacing = 40
        horizontalContainer.alignment = .centerY
        horizontalContainer.distribution = .fill
        horizontalContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(horizontalContainer)
        
        // Left Control Panel
        let leftPanel = NSView()
        leftPanel.translatesAutoresizingMaskIntoConstraints = false
        leftPanel.wantsLayer = true
        leftPanel.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.9).cgColor
        leftPanel.layer?.cornerRadius = 16
        leftPanel.layer?.borderWidth = 1
        leftPanel.layer?.borderColor = NSColor(white: 0.3, alpha: 0.3).cgColor
        
        // Title
        titleLabel = NSTextField(labelWithString: "SYSTEMS CHECK")
        titleLabel.font = NSFont(name: "SF Pro Display", size: 32) ?? NSFont.boldSystemFont(ofSize: 32)
        titleLabel.textColor = NSColor.white
        titleLabel.alignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Subtitle
        subtitleLabel = NSTextField(labelWithString: "INITIALIZING CAMERA POSITIONING VERIFICATION")
        subtitleLabel.font = NSFont(name: "SF Mono", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        subtitleLabel.alignment = .left
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Progress container
        progressContainer = NSView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        
        setupProgressIndicators()
        
        // Add elements to left panel
        leftPanel.addSubview(titleLabel)
        leftPanel.addSubview(subtitleLabel)
        leftPanel.addSubview(progressContainer)
        
        // 3D Scene View (Right side)
        sceneView = SCNView()
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.backgroundColor = NSColor.clear
        sceneView.allowsCameraControl = false
        sceneView.autoenablesDefaultLighting = true
        sceneView.antialiasingMode = .multisampling4X
        sceneView.wantsLayer = true
        sceneView.layer?.cornerRadius = 16
        sceneView.layer?.borderWidth = 1
        sceneView.layer?.borderColor = NSColor(white: 0.3, alpha: 0.3).cgColor
        
        // Add to horizontal container
        horizontalContainer.addArrangedSubview(leftPanel)
        horizontalContainer.addArrangedSubview(sceneView)
        
        NSLayoutConstraint.activate([
            // Background
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Horizontal container
            horizontalContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            horizontalContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            horizontalContainer.widthAnchor.constraint(equalToConstant: 1100),
            horizontalContainer.heightAnchor.constraint(equalToConstant: 600),
            
            // Left panel
            leftPanel.widthAnchor.constraint(equalToConstant: 400),
            leftPanel.heightAnchor.constraint(equalTo: horizontalContainer.heightAnchor),
            
            // Left panel content
            titleLabel.topAnchor.constraint(equalTo: leftPanel.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor, constant: -30),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor, constant: 30),
            subtitleLabel.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor, constant: -30),
            
            progressContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            progressContainer.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor, constant: 30),
            progressContainer.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor, constant: -30),
            progressContainer.bottomAnchor.constraint(lessThanOrEqualTo: leftPanel.bottomAnchor, constant: -30),
            
            // 3D Scene
            sceneView.widthAnchor.constraint(equalToConstant: 660),
            sceneView.heightAnchor.constraint(equalTo: horizontalContainer.heightAnchor)
        ])
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
        button.widthAnchor.constraint(equalToConstant: 240).isActive = true
        
        // Hover effect
        let trackingArea = NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: 240, height: 44),
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: button,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)
        
        return button
    }
    
    private func setupProgressIndicators() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 20
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addSubview(stackView)
        
        for i in 0..<totalSteps {
            let rowContainer = NSView()
            rowContainer.translatesAutoresizingMaskIntoConstraints = false
            
            // Progress indicator circle
            let indicator = NSView()
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.wantsLayer = true
            indicator.layer?.cornerRadius = 8
            indicator.layer?.borderWidth = 2
            indicator.widthAnchor.constraint(equalToConstant: 16).isActive = true
            indicator.heightAnchor.constraint(equalToConstant: 16).isActive = true
            progressIndicators.append(indicator)
            
            // Step label
            let label = NSTextField(labelWithString: stepTitles[i])
            label.font = NSFont(name: "SF Mono", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            label.textColor = NSColor(white: 0.6, alpha: 1.0)
            label.translatesAutoresizingMaskIntoConstraints = false
            progressLabels.append(label)
            
            // Check button (✓)
            let checkButton = NSButton()
            checkButton.title = "✓"
            checkButton.font = NSFont.systemFont(ofSize: 14, weight: .bold)
            checkButton.isBordered = false
            checkButton.wantsLayer = true
            checkButton.layer?.backgroundColor = NSColor.clear.cgColor
            checkButton.layer?.cornerRadius = 12
            checkButton.layer?.borderWidth = 1
            checkButton.layer?.borderColor = NSColor(white: 0.4, alpha: 0.6).cgColor
            checkButton.contentTintColor = NSColor(white: 0.4, alpha: 0.6)
            checkButton.translatesAutoresizingMaskIntoConstraints = false
            checkButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
            checkButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
            checkButton.tag = i
            checkButton.target = self
            checkButton.action = #selector(checkButtonTapped(_:))
            checkButton.isHidden = true // Initially hidden
            checkButtons.append(checkButton)
            
            // X button (✗)
            let xButton = NSButton()
            xButton.title = "✗"
            xButton.font = NSFont.systemFont(ofSize: 14, weight: .bold)
            xButton.isBordered = false
            xButton.wantsLayer = true
            xButton.layer?.backgroundColor = NSColor.clear.cgColor
            xButton.layer?.cornerRadius = 12
            xButton.layer?.borderWidth = 1
            xButton.layer?.borderColor = NSColor(white: 0.4, alpha: 0.6).cgColor
            xButton.contentTintColor = NSColor(white: 0.4, alpha: 0.6)
            xButton.translatesAutoresizingMaskIntoConstraints = false
            xButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
            xButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
            xButton.tag = i
            xButton.target = self
            xButton.action = #selector(xButtonTapped(_:))
            xButton.isHidden = true // Initially hidden
            xButtons.append(xButton)
            
            rowContainer.addSubview(indicator)
            rowContainer.addSubview(label)
            rowContainer.addSubview(checkButton)
            rowContainer.addSubview(xButton)
            
            NSLayoutConstraint.activate([
                indicator.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor),
                indicator.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 12),
                label.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
                
                // X button on the right
                xButton.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
                xButton.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
                
                // Check button next to X button
                checkButton.trailingAnchor.constraint(equalTo: xButton.leadingAnchor, constant: -8),
                checkButton.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
                
                // Label takes remaining space
                label.trailingAnchor.constraint(lessThanOrEqualTo: checkButton.leadingAnchor, constant: -12),
                rowContainer.heightAnchor.constraint(equalToConstant: 32)
            ])
            
            stackView.addArrangedSubview(rowContainer)
        }
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: progressContainer.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: progressContainer.bottomAnchor, constant: -20)
        ])
    }
    
    private func setup3DScene() {
        scene = SCNScene()
        
        print("Attempting to locate pacman0.usdc...")
        
        // Try multiple approaches to load the pacman USDC model
        var modelURL: URL?
        
        // Try direct file path first
        let directPath = "/Users/yadinsoffer/Desktop/Twelve/Sources/ZEDCameraViewer/pacman0.usdc"
        if FileManager.default.fileExists(atPath: directPath) {
            modelURL = URL(fileURLWithPath: directPath)
            print("✓ Found pacman0.usdc at direct path: \(directPath)")
        } else {
            print("✗ File does not exist at direct path: \(directPath)")
        }
        
        // Try Bundle.module as fallback (for SPM resources)
        if modelURL == nil {
            if let bundleURL = Bundle.module.url(forResource: "pacman0", withExtension: "usdc") {
                modelURL = bundleURL
                print("✓ Found pacman0.usdc in Bundle.module at: \(bundleURL.path)")
            } else {
                print("✗ Bundle.module.url returned nil for pacman0.usdc")
            }
        }
        
        // Try Bundle.main as last fallback
        if modelURL == nil {
            if let mainURL = Bundle.main.url(forResource: "pacman0", withExtension: "usdc") {
                modelURL = mainURL
                print("✓ Found pacman0.usdc in Bundle.main at: \(mainURL.path)")
            } else {
                print("✗ Bundle.main.url returned nil for pacman0.usdc")
            }
        }
        
        guard let url = modelURL else {
            print("Could not find pacman0.usdc model in any location")
            createFallbackGeometry()
            return
        }
        
        do {
            print("Attempting to load USDC from: \(url.path)")
            
            // USDC files load well in SceneKit
            let modelScene = try SCNScene(url: url, options: nil)
            print("✓ USDC loaded successfully, child nodes: \(modelScene.rootNode.childNodes.count)")
            
            // Try to find the main geometry node
            var foundNode: SCNNode?
            
            // First try to get the first child with geometry
            for child in modelScene.rootNode.childNodes {
                if child.geometry != nil {
                    foundNode = child
                    print("Found geometry node: \(child.name ?? "unnamed")")
                    break
                }
                // Also check nested children
                for grandchild in child.childNodes {
                    if grandchild.geometry != nil {
                        foundNode = grandchild
                        print("Found nested geometry node: \(grandchild.name ?? "unnamed")")
                        break
                    }
                }
                if foundNode != nil { break }
            }
            
            // If no direct geometry found, use the first child and let it include its children
            if foundNode == nil && !modelScene.rootNode.childNodes.isEmpty {
                foundNode = modelScene.rootNode.childNodes.first
                print("Using first child node as container: \(foundNode?.name ?? "unnamed")")
            }
            
            if let modelNode = foundNode {
                pacmanNode = modelNode.clone()
                pacmanNode.position = SCNVector3(0, -1.0, 0) // Move more down to center better
                pacmanNode.scale = SCNVector3(0.022, 0.022, 0.022) // Zoomed out a little more
                
                // Flip right-side up and add slight angle to show side
                // X rotation to flip right-side up, Y rotation with slight angle for depth
                pacmanNode.eulerAngles = SCNVector3(-Float.pi/2, -Float.pi/2 + 0.3, 0) // Flip up + slight side angle
                
                scene.rootNode.addChildNode(pacmanNode)
                print("✓ Successfully added pacman0 node to scene with smaller scale")
            } else {
                print("No suitable node found in USDC model")
                createFallbackGeometry()
            }
        } catch {
            print("Error loading USDC model: \(error)")
            createFallbackGeometry()
        }
        
        // Setup camera
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60 // Wider field of view for better visibility
        cameraNode.position = SCNVector3(0, 0, 8) // Start with front view
        scene.rootNode.addChildNode(cameraNode)
        
        // Add 3D grid system - do this after camera setup
        addGridFloor()
        
        // Setup atmospheric lighting with glow effects
        setupAtmosphericLighting()
        
        sceneView.scene = scene
        sceneView.pointOfView = cameraNode
    }
    
    private func addGridFloor() {
        // Create 3D infinite-looking grid system
        create3DGrid()
    }
    
    private func create3DGrid() {
        let gridContainer = SCNNode()
        
        // Create horizontal grid plane (floor)
        let floorGrid = createGridPlane(width: 50, height: 50, divisions: 50)
        floorGrid.position = SCNVector3(0, -4, 0)
        floorGrid.eulerAngles = SCNVector3(-Float.pi/2, 0, 0)
        gridContainer.addChildNode(floorGrid)
        
        // Create vertical grid planes for depth effect
        let backGrid = createGridPlane(width: 50, height: 30, divisions: 50)
        backGrid.position = SCNVector3(0, 11, -25)
        gridContainer.addChildNode(backGrid)
        
        let rightGrid = createGridPlane(width: 50, height: 30, divisions: 50)
        rightGrid.position = SCNVector3(25, 11, 0)
        rightGrid.eulerAngles = SCNVector3(0, Float.pi/2, 0)
        gridContainer.addChildNode(rightGrid)
        
        let leftGrid = createGridPlane(width: 50, height: 30, divisions: 50)
        leftGrid.position = SCNVector3(-25, 11, 0)
        leftGrid.eulerAngles = SCNVector3(0, -Float.pi/2, 0)
        gridContainer.addChildNode(leftGrid)
        
        scene.rootNode.addChildNode(gridContainer)
    }
    
    private func createGridPlane(width: Float, height: Float, divisions: Int) -> SCNNode {
        let plane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        let node = SCNNode(geometry: plane)
        
        // Create wireframe material
        let material = SCNMaterial()
        material.fillMode = .lines
        material.diffuse.contents = NSColor(white: 0.3, alpha: 0.4)
        material.lightingModel = .constant
        material.isDoubleSided = true
        
        plane.materials = [material]
        
        // Add subdivision for grid effect
        plane.widthSegmentCount = divisions
        plane.heightSegmentCount = Int(Float(divisions) * height / width)
        
        return node
    }
    

    
    private func setupAtmosphericLighting() {
        // Ambient light (lower intensity for atmosphere)
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = NSColor(white: 0.2, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        // Key light with subtle blue tint
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = NSColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        keyLight.light?.intensity = 800
        keyLight.position = SCNVector3(5, 8, 5)
        keyLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLight)
        
        // Rim light for glow effect
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .spot
        rimLight.light?.color = NSColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0)
        rimLight.light?.intensity = 500
        rimLight.light?.spotInnerAngle = 30
        rimLight.light?.spotOuterAngle = 80
        rimLight.position = SCNVector3(-3, 2, -5)
        rimLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLight)
        
        // Bottom fill light
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .omni
        fillLight.light?.color = NSColor(white: 0.6, alpha: 1.0)
        fillLight.light?.intensity = 200
        fillLight.position = SCNVector3(0, -2, 0)
        scene.rootNode.addChildNode(fillLight)
    }
    

    
    private func createFallbackGeometry() {
        print("Using fallback geometry - USDZ model not available")
        
        // Create a more distinctive fallback - a white wireframe cube
        let geometry = SCNBox(width: 2.0, height: 2.0, length: 2.0, chamferRadius: 0.1)
        
        // Create white material
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.white
        material.fillMode = .lines // Wireframe
        material.lightingModel = .constant
        geometry.materials = [material]
        
        pacmanNode = SCNNode(geometry: geometry)
        pacmanNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(pacmanNode)
        
        // Add rotation animation to make it more interesting
        let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 4.0)
        let repeatAction = SCNAction.repeatForever(rotateAction)
        pacmanNode.runAction(repeatAction)
    }
    
    private func startSystemsCheck() {
        updateProgressUI()
        animateToCurrentView()
        
        // Initial subtitle is set by animateToCurrentView()
    }
    
    private func updateProgressUI() {
        for i in 0..<totalSteps {
            let indicator = progressIndicators[i]
            let label = progressLabels[i]
            let checkButton = checkButtons[i]
            let xButton = xButtons[i]
            let stepState = stepStates[i]
            
            // Update button appearance based on state
            updateButtonAppearance(checkButton: checkButton, xButton: xButton, state: stepState)
            
            if i < currentStep {
                // Completed step - show the selection that was made
                indicator.layer?.backgroundColor = NSColor.white.cgColor
                indicator.layer?.borderColor = NSColor.white.cgColor
                label.textColor = NSColor.white
                
                // Show the selected button
                switch stepState {
                case .confirmed:
                    checkButton.isHidden = false
                    xButton.isHidden = true
                case .rejected:
                    checkButton.isHidden = true
                    xButton.isHidden = false
                case .pending:
                    checkButton.isHidden = true
                    xButton.isHidden = true
                }
                
                indicator.layer?.removeAnimation(forKey: "pulse")
            } else if i == currentStep {
                // Current step - show both check/X buttons for selection
                indicator.layer?.backgroundColor = NSColor(white: 0.8, alpha: 1.0).cgColor
                indicator.layer?.borderColor = NSColor.white.cgColor
                label.textColor = NSColor.white
                checkButton.isHidden = false
                xButton.isHidden = false
                
                // Pulsing animation for current step
                let pulseAnimation = CABasicAnimation(keyPath: "opacity")
                pulseAnimation.fromValue = 0.5
                pulseAnimation.toValue = 1.0
                pulseAnimation.duration = 1.0
                pulseAnimation.repeatCount = .infinity
                pulseAnimation.autoreverses = true
                indicator.layer?.add(pulseAnimation, forKey: "pulse")
            } else {
                // Future step
                indicator.layer?.backgroundColor = NSColor.clear.cgColor
                indicator.layer?.borderColor = NSColor(white: 0.4, alpha: 1.0).cgColor
                label.textColor = NSColor(white: 0.4, alpha: 1.0)
                checkButton.isHidden = true
                xButton.isHidden = true
                indicator.layer?.removeAnimation(forKey: "pulse")
            }
        }
    }
    
    private func updateButtonAppearance(checkButton: NSButton, xButton: NSButton, state: StepState) {
        switch state {
        case .pending:
            // Default appearance - grey border and text
            checkButton.layer?.borderColor = NSColor(white: 0.4, alpha: 0.6).cgColor
            checkButton.layer?.backgroundColor = NSColor.clear.cgColor
            checkButton.contentTintColor = NSColor(white: 0.4, alpha: 0.6)
            
            xButton.layer?.borderColor = NSColor(white: 0.4, alpha: 0.6).cgColor
            xButton.layer?.backgroundColor = NSColor.clear.cgColor
            xButton.contentTintColor = NSColor(white: 0.4, alpha: 0.6)
            
        case .confirmed:
            // Selected check - white background with white checkmark
            checkButton.layer?.borderColor = NSColor.white.cgColor
            checkButton.layer?.backgroundColor = NSColor.white.cgColor
            checkButton.contentTintColor = NSColor.black // Black checkmark on white background
            
        case .rejected:
            // Selected X - white background with white X
            xButton.layer?.borderColor = NSColor.white.cgColor
            xButton.layer?.backgroundColor = NSColor.white.cgColor
            xButton.contentTintColor = NSColor.black // Black X on white background
        }
    }
    
    private func animateToCurrentView() {
        guard currentStep < cameraSettings.count else { return }
        
        let setting = cameraSettings[currentStep]
        
        // Animate camera position and zoom
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Reset camera transform first to avoid accumulating rotations
        cameraNode.transform = SCNMatrix4Identity
        cameraNode.position = setting.position
        cameraNode.look(at: SCNVector3(0, 0, 0))
        
        // Apply zoom by adjusting field of view (smaller FOV = more zoom)
        let baseFOV: Float = 60.0
        cameraNode.camera?.fieldOfView = CGFloat(baseFOV / setting.zoom)
        
        SCNTransaction.commit()
        
        // Update subtitle with animation to show the description
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            subtitleLabel.animator().alphaValue = 0.0
        } completionHandler: {
            self.subtitleLabel.stringValue = setting.description
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                self.subtitleLabel.animator().alphaValue = 1.0
            }
        }
    }
    
    @objc private func checkButtonTapped(_ sender: NSButton) {
        let stepIndex = sender.tag
        guard stepIndex == currentStep else { return }
        
        // Mark step as confirmed
        stepStates[stepIndex] = .confirmed
        
        // Move to next step
        currentStep += 1
        
        if currentStep >= totalSteps {
            // All steps completed, proceed to main app
            proceedToMainApp()
        } else {
            // Update UI and move to next step
            updateProgressUI()
            animateToCurrentView()
        }
        
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
    
    @objc private func xButtonTapped(_ sender: NSButton) {
        let stepIndex = sender.tag
        guard stepIndex == currentStep else { return }
        
        // Mark step as rejected
        stepStates[stepIndex] = .rejected
        
        // Move to next step
        currentStep += 1
        
        if currentStep >= totalSteps {
            // All steps completed, proceed to main app
            proceedToMainApp()
        } else {
            // Update UI and move to next step
            updateProgressUI()
            animateToCurrentView()
        }
        
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
        let wiringVC = WiringViewController()
        
        // Preserve window size during transition
        let currentFrame = self.view.window?.frame
        
        // Smooth transition
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            self.view.animator().alphaValue = 0.0
        } completionHandler: {
            self.view.window?.contentViewController = wiringVC
            
            // Restore window size after transition
            if let frame = currentFrame {
                self.view.window?.setFrame(frame, display: true, animate: false)
            }
        }
    }
}

// MARK: - Button hover effects
extension NSButton {
    override open func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 0.8
            if let layer = self.layer {
                layer.borderColor = NSColor.white.cgColor
            }
        }
    }
    
    override open func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
            if let layer = self.layer {
                layer.borderColor = NSColor(white: 0.6, alpha: 0.8).cgColor
            }
        }
    }
}
