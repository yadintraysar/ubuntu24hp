import AppKit
import Foundation
import CoreLocation

final class LoginViewController: NSViewController, CLLocationManagerDelegate {
    private var logoImageView: NSImageView!
    private var nameField: NSTextField!
    private var missionPopup: NSPopUpButton!
    private var locationField: NSTextField!
    private var dateLabel: NSTextField!
    private var timeLabel: NSTextField!
    private var continueButton: NSButton!
    private let entryLogger = EntryLogger()
    private var capabilityButton: NSButton!
    private let locationManager = CLLocationManager()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        // Top-right Capability Demonstration button
        capabilityButton = NSButton(title: "Capability Demonstration", target: self, action: #selector(openCapabilityDemo))
        capabilityButton.translatesAutoresizingMaskIntoConstraints = false
        capabilityButton.isBordered = false
        capabilityButton.wantsLayer = true
        capabilityButton.layer?.backgroundColor = NSColor(white: 0.2, alpha: 0.8).cgColor
        capabilityButton.layer?.cornerRadius = 8
        capabilityButton.layer?.borderWidth = 1
        capabilityButton.layer?.borderColor = NSColor(white: 0.6, alpha: 0.8).cgColor
        capabilityButton.contentTintColor = NSColor.white
        capabilityButton.font = NSFont(name: "SF Mono", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
        capabilityButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        capabilityButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        view.addSubview(capabilityButton)
        NSLayoutConstraint.activate([
            capabilityButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            capabilityButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])

        // Logo
        logoImageView = NSImageView()
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        if let image = loadImageFromBundle(named: "traysar-icon.png") {
            logoImageView.image = image
        }
        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.widthAnchor.constraint(equalToConstant: 120).isActive = true
        logoImageView.heightAnchor.constraint(equalToConstant: 120).isActive = true

        // Title
        let title = NSTextField(labelWithString: "Traysar Spatial Awareness")
        title.font = NSFont.boldSystemFont(ofSize: 20)
        title.alignment = .center

        // Name field
        let nameLabel = NSTextField(labelWithString: "Name")
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        nameField = NSTextField(string: "")
        nameField.placeholderString = "Enter your name"
        nameField.isEditable = true
        nameField.isSelectable = true
        nameField.isBezeled = true
        nameField.isBordered = true
        nameField.drawsBackground = true
        nameField.backgroundColor = .textBackgroundColor
        nameField.focusRingType = .default
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalToConstant: 320).isActive = true

        // Mission popup
        let missionLabel = NSTextField(labelWithString: "Mission")
        missionLabel.font = NSFont.systemFont(ofSize: 13)
        missionPopup = NSPopUpButton()
        missionPopup.addItems(withTitles: ["Development", "Field Test 1", "Field Test 2", "Field Test 3"])
        missionPopup.translatesAutoresizingMaskIntoConstraints = false
        missionPopup.widthAnchor.constraint(equalToConstant: 320).isActive = true

        // Location (auto populated)
        let locationLabel = NSTextField(labelWithString: "📍 Location")
        locationLabel.font = NSFont.systemFont(ofSize: 13)
        locationField = NSTextField(string: "Locating…")
        locationField.isEditable = false
        locationField.isBezeled = true
        locationField.isBordered = true
        locationField.drawsBackground = true
        locationField.backgroundColor = .textBackgroundColor
        locationField.translatesAutoresizingMaskIntoConstraints = false
        locationField.widthAnchor.constraint(equalToConstant: 320).isActive = true

        // Datetime
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateLabel = NSTextField(labelWithString: dateFormatter.string(from: now))

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium
        timeLabel = NSTextField(labelWithString: timeFormatter.string(from: now))

        // Continue button (custom styled smaller, light grey)
        continueButton = NSButton(title: "Continue", target: self, action: #selector(continueTapped))
        continueButton.isBordered = false
        continueButton.wantsLayer = true
        continueButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
        continueButton.layer?.cornerRadius = 8
        continueButton.contentTintColor = .darkGray
        continueButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        continueButton.heightAnchor.constraint(equalToConstant: 34).isActive = true
        continueButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
        continueButton.keyEquivalent = "\r"
        continueButton.keyEquivalentModifierMask = []

        let formGrid = NSGridView(views: [
            [nameLabel, nameField],
            [missionLabel, missionPopup],
            [locationLabel, locationField],
            [NSTextField(labelWithString: "Date"), dateLabel],
            [NSTextField(labelWithString: "Time"), timeLabel]
        ])
        formGrid.rowSpacing = 8
        formGrid.columnSpacing = 12

        stack.addArrangedSubview(logoImageView)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(formGrid)
        stack.addArrangedSubview(continueButton)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Location setup
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.startUpdatingLocation()

        // Fallback to IP-based geolocation if CoreLocation doesn't respond quickly
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.locationField.stringValue == "Locating…" {
                self.fetchIPLocationFallback()
            }
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.makeFirstResponder(nameField)
    }

    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        // Immediately show lat/long so the user sees something even if reverse geocoding is slow
        let latLong = String(format: "%.5f, %.5f", loc.coordinate.latitude, loc.coordinate.longitude)
        DispatchQueue.main.async { self.locationField.stringValue = latLong }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(loc) { places, _ in
            if let p = places?.first {
                let city = p.locality ?? p.subLocality ?? ""
                let admin = p.administrativeArea ?? ""
                let country = p.country ?? ""
                let composed = [city, admin, country].filter { !$0.isEmpty }.joined(separator: ", ")
                DispatchQueue.main.async { self.locationField.stringValue = composed.isEmpty ? latLong : composed }
            } else {
                DispatchQueue.main.async { self.locationField.stringValue = latLong }
            }
        }
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.locationField.stringValue = "Unavailable" }
        fetchIPLocationFallback()
    }

    // macOS 11+
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorization(manager.authorizationStatus)
    }

    // macOS <11
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorization(status)
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            DispatchQueue.main.async { self.locationField.stringValue = "Denied" }
            fetchIPLocationFallback()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    // MARK: - IP-based geolocation fallback (no permissions needed)
    private func fetchIPLocationFallback() {
        guard let url = URL(string: "https://ipapi.co/json/") else { return }
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            let city = (json["city"] as? String) ?? ""
            let region = (json["region"] as? String) ?? (json["region_code"] as? String) ?? ""
            let country = (json["country_name"] as? String) ?? ""
            let lat = (json["latitude"] as? Double) ?? (json["lat"] as? Double) ?? 0
            let lon = (json["longitude"] as? Double) ?? (json["lon"] as? Double) ?? 0
            let composed = [city, region, country].filter { !$0.isEmpty }.joined(separator: ", ")
            let coords = String(format: "%.5f, %.5f", lat, lon)
            DispatchQueue.main.async {
                if self.locationField.stringValue == "Locating…" || self.locationField.stringValue.isEmpty || self.locationField.stringValue == "Denied" || self.locationField.stringValue == "Unavailable" {
                    self.locationField.stringValue = composed.isEmpty ? coords : composed
                }
            }
        }
        task.resume()
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

    @objc private func continueTapped() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { NSSound.beep(); return }
        entryLogger.appendEntry(name: name)
        
        // Preserve window size during transition
        let currentFrame = self.view.window?.frame
        
        // Check if Development mode is selected to skip Systems Check
        let selectedMission = missionPopup.titleOfSelectedItem ?? ""
        if selectedMission == "Development" {
            // Skip directly to main camera view
            let mainVC = CameraViewController()
            self.view.window?.contentViewController = mainVC
        } else {
            // Go through Systems Check first
            let systemsCheckVC = SystemsCheckViewController()
            self.view.window?.contentViewController = systemsCheckVC
        }
        
        // Restore window size after transition
        if let frame = currentFrame {
            self.view.window?.setFrame(frame, display: true, animate: false)
        }
    }

    @objc private func openCapabilityDemo() {
        let demoVC = CapabilityDemoViewController()
        // Present as separate window so user can explore before logging in
        let window = NSWindow(contentViewController: demoVC)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "Capability Demonstration"
        window.setFrame(NSRect(x: 0, y: 0, width: 1100, height: 700), display: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}


