import AppKit
import Foundation

final class MicCheckViewController: NSViewController {
    private var backgroundView: NSView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var microphoneImageView: NSImageView!
    private var soundWaveContainer: NSView!
    private var soundWaves: [NSView] = []
    private var confirmButton: NSButton!
    
    private var waveTimer: Timer?
    private var isConfirmed = false
    
    override func loadView() {
        view = NSView()
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startSoundWaveAnimation()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        waveTimer?.invalidate()
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
        titleLabel = NSTextField(labelWithString: "MIC CHECK")
        titleLabel.font = NSFont(name: "SF Pro Display", size: 48) ?? NSFont.boldSystemFont(ofSize: 48)
        titleLabel.textColor = NSColor.white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Subtitle
        subtitleLabel = NSTextField(labelWithString: "VERIFY MICROPHONE FUNCTIONALITY")
        subtitleLabel.font = NSFont(name: "SF Mono", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Microphone container
        let micContainer = NSView()
        micContainer.translatesAutoresizingMaskIntoConstraints = false
        micContainer.wantsLayer = true
        micContainer.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.9).cgColor
        micContainer.layer?.cornerRadius = 16
        micContainer.layer?.borderWidth = 1
        micContainer.layer?.borderColor = NSColor(white: 0.3, alpha: 0.3).cgColor
        
        // Microphone image
        microphoneImageView = NSImageView()
        microphoneImageView.translatesAutoresizingMaskIntoConstraints = false
        microphoneImageView.imageScaling = .scaleProportionallyUpOrDown
        
        // Load microphone image
        if let micImage = loadImageFromBundle(named: "microphone.png") {
            microphoneImageView.image = micImage
        }
        
        // Sound wave container
        soundWaveContainer = NSView()
        soundWaveContainer.translatesAutoresizingMaskIntoConstraints = false
        
        setupSoundWaves()
        
        // Confirm button
        confirmButton = createFuturisticButton(title: "MIC CONFIRMED", action: #selector(confirmButtonTapped))
        
        // Layout
        micContainer.addSubview(microphoneImageView)
        micContainer.addSubview(soundWaveContainer)
        
        mainContainer.addSubview(titleLabel)
        mainContainer.addSubview(subtitleLabel)
        mainContainer.addSubview(micContainer)
        mainContainer.addSubview(confirmButton)
        
        NSLayoutConstraint.activate([
            // Background
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Main container
            mainContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mainContainer.widthAnchor.constraint(equalToConstant: 800),
            mainContainer.heightAnchor.constraint(equalToConstant: 600),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: mainContainer.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            
            // Mic container
            micContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 60),
            micContainer.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor),
            micContainer.widthAnchor.constraint(equalToConstant: 500),
            micContainer.heightAnchor.constraint(equalToConstant: 300),
            
            // Microphone image (centered in container)
            microphoneImageView.centerXAnchor.constraint(equalTo: micContainer.centerXAnchor),
            microphoneImageView.centerYAnchor.constraint(equalTo: micContainer.centerYAnchor),
            microphoneImageView.widthAnchor.constraint(equalToConstant: 120),
            microphoneImageView.heightAnchor.constraint(equalToConstant: 120),
            
            // Sound waves container (to the right of microphone)
            soundWaveContainer.leadingAnchor.constraint(equalTo: microphoneImageView.trailingAnchor, constant: 30),
            soundWaveContainer.centerYAnchor.constraint(equalTo: microphoneImageView.centerYAnchor),
            soundWaveContainer.widthAnchor.constraint(equalToConstant: 200),
            soundWaveContainer.heightAnchor.constraint(equalToConstant: 120),
            
            // Confirm button
            confirmButton.topAnchor.constraint(equalTo: micContainer.bottomAnchor, constant: 40),
            confirmButton.centerXAnchor.constraint(equalTo: mainContainer.centerXAnchor)
        ])
    }
    
    private func setupSoundWaves() {
        // Create 4 traditional sound wave arcs emanating from microphone
        for i in 0..<4 {
            let wave = NSView()
            wave.translatesAutoresizingMaskIntoConstraints = false
            wave.wantsLayer = true
            wave.layer?.cornerRadius = CGFloat(20 + i * 15) // Semi-circular appearance
            wave.layer?.borderWidth = 2
            wave.layer?.borderColor = NSColor(white: 0.6, alpha: 0.6).cgColor
            wave.layer?.backgroundColor = NSColor.clear.cgColor
            
            // Make it look like a sound wave arc by clipping
            wave.layer?.masksToBounds = true
            
            soundWaveContainer.addSubview(wave)
            soundWaves.append(wave)
            
            let waveSize = CGFloat(40 + i * 30)
            
            // Position waves to emanate from left side (where microphone is)
            NSLayoutConstraint.activate([
                wave.leadingAnchor.constraint(equalTo: soundWaveContainer.leadingAnchor, constant: -waveSize/2),
                wave.centerYAnchor.constraint(equalTo: soundWaveContainer.centerYAnchor),
                wave.widthAnchor.constraint(equalToConstant: waveSize),
                wave.heightAnchor.constraint(equalToConstant: waveSize)
            ])
        }
    }
    
    private func startSoundWaveAnimation() {
        // Animate sound waves with expanding effect
        for (index, wave) in soundWaves.enumerated() {
            let delay = Double(index) * 0.2 // Stagger the animations
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.animateWave(wave)
            }
        }
    }
    
    private func animateWave(_ wave: NSView) {
        // Create traditional sound wave animation - opacity pulsing
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.1
        opacityAnimation.toValue = 0.8
        opacityAnimation.duration = 1.0
        opacityAnimation.repeatCount = .infinity
        opacityAnimation.autoreverses = true
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Slight scale animation for more dynamic effect
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.95
        scaleAnimation.toValue = 1.05
        scaleAnimation.duration = 1.0
        scaleAnimation.repeatCount = .infinity
        scaleAnimation.autoreverses = true
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [opacityAnimation, scaleAnimation]
        groupAnimation.duration = 1.0
        groupAnimation.repeatCount = .infinity
        
        wave.layer?.add(groupAnimation, forKey: "soundWave")
    }
    
    private func loadImageFromBundle(named imageName: String) -> NSImage? {
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
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        
        return button
    }
    
    @objc private func confirmButtonTapped() {
        guard !isConfirmed else { return }
        isConfirmed = true
        
        // Stop sound wave animations
        waveTimer?.invalidate()
        for wave in soundWaves {
            wave.layer?.removeAllAnimations()
            wave.layer?.opacity = 0.3 // Keep visible but static
        }
        
        // Update subtitle
        subtitleLabel.stringValue = "MICROPHONE VERIFIED - PROCEEDING TO MAIN APP"
        
        // Button feedback
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            confirmButton.animator().alphaValue = 0.6
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                self.confirmButton.animator().alphaValue = 1.0
            }
        }
        
        // Auto-continue to main app after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.proceedToMainApp()
        }
    }
    
    private func proceedToMainApp() {
        let cameraVC = CameraViewController()
        
        // Preserve window size during transition
        let currentFrame = self.view.window?.frame
        
        // Smooth transition
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            self.view.animator().alphaValue = 0.0
        } completionHandler: {
            self.view.window?.contentViewController = cameraVC
            
            // Restore window size after transition
            if let frame = currentFrame {
                self.view.window?.setFrame(frame, display: true, animate: false)
            }
        }
    }
}
