import AppKit
import Foundation
import WebKit

final class StatsSidebarView: NSView {
    private var headerContainer: NSView!
    private var logoImageView: NSImageView!
    private var titleLabel: NSTextField!
    private var listStack: NSStackView!
    private var secondWebView: WKWebView!
    private var secondWebViewContainer: NSView!
    private var secondWebViewTitleLabel: NSTextField!
    private var webView: WKWebView!
    private var webViewContainer: NSView!
    private var webViewTitleLabel: NSTextField!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.1).cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        setupHeader()
        setupStats()
        setupConstraints()

        // Seed with dummy metrics
        addMetric(name: "Barometer", value: "1013.2 hPa")
        addMetric(name: "Altitude", value: "23.4 m")
        addMetric(name: "Depth", value: "—")
        addMetric(name: "FPS (Primary)", value: "29.7")
        addMetric(name: "Jitter", value: "42 ms")
        addMetric(name: "Dropped", value: "0.2%")
        
        // Setup web view sections
        setupSecondWebView()
        setupWebView()
    }
    
    private func setupHeader() {
        // Create header container
        headerContainer = NSView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.wantsLayer = true
        headerContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
        headerContainer.layer?.cornerRadius = 4
        
        // Create logo image view
        logoImageView = NSImageView()
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.wantsLayer = true
        
        // Load the Traysar icon (prefer SPM bundle resource)
        if let logoImage = loadImageFromBundle(named: "traysar-icon.png") {
            logoImageView.image = logoImage
        } else if let bundleImage = NSImage(named: "traysar-icon") {
            // Named asset fallback
            logoImageView.image = bundleImage
        } else if let directImage = NSImage(contentsOfFile: "/Users/yadinsoffer/Desktop/Twelve/traysar-icon.png") {
            // Absolute-path fallback (dev environment)
            logoImageView.image = directImage
        } else {
            // Last resort fallback
            logoImageView.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Traysar")
        }
        
        headerContainer.addSubview(logoImageView)
        addSubview(headerContainer)
    }
    
    private func setupStats() {
        titleLabel = NSTextField(labelWithString: "STATS")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .heavy)
        titleLabel.alignment = .center
        titleLabel.textColor = .tertiaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        listStack = NSStackView()
        listStack.orientation = .vertical
        listStack.spacing = 6
        listStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(listStack)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header container
            headerContainer.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            headerContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            headerContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            headerContainer.heightAnchor.constraint(equalToConstant: 50),
            
            // Logo within header
            logoImageView.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 32),
            logoImageView.heightAnchor.constraint(equalToConstant: 32),
            
            // Stats title
            titleLabel.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            // Stats list
            listStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            listStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            listStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
    }

    private func addMetric(name: String, value: String) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = NSFont(name: "Menlo", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        nameLabel.textColor = .secondaryLabelColor

        let spacer = NSView()

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont(name: "Menlo", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
        valueLabel.textColor = .labelColor

        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(valueLabel)

        listStack.addArrangedSubview(row)
    }
    
    private func setupSecondWebView() {
        // Create second web view title
        secondWebViewTitleLabel = NSTextField(labelWithString: "CONTROL PANEL")
        secondWebViewTitleLabel.font = NSFont.systemFont(ofSize: 16, weight: .heavy)
        secondWebViewTitleLabel.alignment = .center
        secondWebViewTitleLabel.textColor = .tertiaryLabelColor
        secondWebViewTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create second web view container
        secondWebViewContainer = NSView()
        secondWebViewContainer.translatesAutoresizingMaskIntoConstraints = false
        secondWebViewContainer.wantsLayer = true
        secondWebViewContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        secondWebViewContainer.layer?.cornerRadius = 6
        secondWebViewContainer.layer?.borderWidth = 1
        secondWebViewContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Configure second WKWebView
        let secondWebViewConfig = WKWebViewConfiguration()
        secondWebViewConfig.allowsAirPlayForMediaPlayback = false
        secondWebViewConfig.mediaTypesRequiringUserActionForPlayback = []
        
        secondWebView = WKWebView(frame: .zero, configuration: secondWebViewConfig)
        secondWebView.translatesAutoresizingMaskIntoConstraints = false
        secondWebView.navigationDelegate = self
        
        // Add subviews
        addSubview(secondWebViewTitleLabel)
        addSubview(secondWebViewContainer)
        secondWebViewContainer.addSubview(secondWebView)
        
        // Setup constraints for second web view
        NSLayoutConstraint.activate([
            // Second web view title positioning
            secondWebViewTitleLabel.topAnchor.constraint(equalTo: listStack.bottomAnchor, constant: 16),
            secondWebViewTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            secondWebViewTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            // Second web view container positioning
            secondWebViewContainer.topAnchor.constraint(equalTo: secondWebViewTitleLabel.bottomAnchor, constant: 8),
            secondWebViewContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            secondWebViewContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            // Control panel height tuned to avoid pushing sidebar upward
            secondWebViewContainer.heightAnchor.constraint(equalToConstant: 220),
            
            // Second web view inside container
            secondWebView.topAnchor.constraint(equalTo: secondWebViewContainer.topAnchor, constant: 4),
            secondWebView.leadingAnchor.constraint(equalTo: secondWebViewContainer.leadingAnchor, constant: 4),
            secondWebView.trailingAnchor.constraint(equalTo: secondWebViewContainer.trailingAnchor, constant: -4),
            secondWebView.bottomAnchor.constraint(equalTo: secondWebViewContainer.bottomAnchor, constant: -4)
        ])
        
        // Load the second HTTP content
        loadSecondWebContent()
    }
    
    private func setupWebView() {
        // Create web view title
        webViewTitleLabel = NSTextField(labelWithString: "LIVE VIEW")
        webViewTitleLabel.font = NSFont.systemFont(ofSize: 16, weight: .heavy)
        webViewTitleLabel.alignment = .center
        webViewTitleLabel.textColor = .tertiaryLabelColor
        webViewTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create web view container
        webViewContainer = NSView()
        webViewContainer.translatesAutoresizingMaskIntoConstraints = false
        webViewContainer.wantsLayer = true
        webViewContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        webViewContainer.layer?.cornerRadius = 6
        webViewContainer.layer?.borderWidth = 1
        webViewContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Configure WKWebView
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.allowsAirPlayForMediaPlayback = false
        webViewConfig.mediaTypesRequiringUserActionForPlayback = []
        
        webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        // Add subviews
        addSubview(webViewTitleLabel)
        addSubview(webViewContainer)
        webViewContainer.addSubview(webView)
        
        // Update constraints to include web view
        NSLayoutConstraint.activate([
            // Web view title positioning
            webViewTitleLabel.topAnchor.constraint(equalTo: secondWebViewContainer.bottomAnchor, constant: 16),
            webViewTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            webViewTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            // Web view container positioning
            webViewContainer.topAnchor.constraint(equalTo: webViewTitleLabel.bottomAnchor, constant: 8),
            webViewContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            webViewContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            webViewContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            // Live view height tuned to fit remaining space without overflow
            webViewContainer.heightAnchor.constraint(equalToConstant: 220),
            
            // Web view inside container
            webView.topAnchor.constraint(equalTo: webViewContainer.topAnchor, constant: 4),
            webView.leadingAnchor.constraint(equalTo: webViewContainer.leadingAnchor, constant: 4),
            webView.trailingAnchor.constraint(equalTo: webViewContainer.trailingAnchor, constant: -4),
            webView.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor, constant: -4)
        ])
        
        // Load the HTTP content
        loadWebContent()
    }
    
    private func loadWebContent() {
        guard let url = URL(string: "http://192.168.1.254:8000") else {
            print("Invalid URL")
            return
        }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func refreshWebContent() {
        loadWebContent()
    }
    
    private func loadSecondWebContent() {
        guard let url = URL(string: "http://192.168.1.254:6081") else {
            print("Invalid second URL")
            return
        }
        
        let request = URLRequest(url: url)
        secondWebView.load(request)
    }
    
    func refreshSecondWebContent() {
        loadSecondWebContent()
    }
}

// MARK: - Resource Loading
private extension StatsSidebarView {
    func loadImageFromBundle(named imageName: String) -> NSImage? {
        // Try SPM resources via Bundle.module
        if let url = Bundle.module.url(forResource: imageName.replacingOccurrences(of: ".png", with: ""), withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // Try main bundle named lookup
        if let img = NSImage(named: imageName.replacingOccurrences(of: ".png", with: "")) {
            return img
        }
        return nil
    }
}

// MARK: - WKNavigationDelegate
extension StatsSidebarView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Show loading state if needed
        print("Started loading web content")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Hide loading state if needed
        print("Finished loading web content")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("Failed to load web content: \(error.localizedDescription)")
        // Handle error state - could show placeholder content
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Web navigation failed: \(error.localizedDescription)")
    }
}


