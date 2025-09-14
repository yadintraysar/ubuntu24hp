import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private var cameraViewController: CameraViewController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure we're a foreground app and active for text input
        NSApplication.shared.setActivationPolicy(.regular)
        setupMainWindow()
        setupMenu()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up any running GStreamer processes
        cameraViewController?.stopAllStreams()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func setupMainWindow() {
        let windowRect = NSRect(x: 100, y: 100, width: 1200, height: 800)
        
        mainWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        mainWindow?.title = "Traysar Spatial Awareness"
        mainWindow?.center()
        mainWindow?.makeKeyAndOrderFront(nil)
        // Enable native full-screen and allow free resizing
        mainWindow?.collectionBehavior.insert(.fullScreenPrimary)
        mainWindow?.minSize = NSSize(width: 800, height: 600)
        mainWindow?.contentMinSize = NSSize(width: 800, height: 600)
        mainWindow?.preservesContentDuringLiveResize = true
        // Try to enter full screen on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let w = self?.mainWindow else { return }
            if !w.styleMask.contains(.fullScreen) {
                w.toggleFullScreen(nil)
            }
        }
        
        // Show login screen first
        mainWindow?.contentViewController = LoginViewController()
    }
    
    private func setupMenu() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit Traysar Spatial Awareness", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Camera menu
        let cameraMenuItem = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
        let cameraMenu = NSMenu(title: "Camera")
        
        cameraMenu.addItem(NSMenuItem(title: "Start All Streams", action: #selector(startAllStreams), keyEquivalent: "s"))
        cameraMenu.addItem(NSMenuItem(title: "Stop All Streams", action: #selector(stopAllStreams), keyEquivalent: "x"))
        cameraMenu.addItem(NSMenuItem.separator())
        cameraMenu.addItem(NSMenuItem(title: "Toggle Camera 0", action: #selector(toggleCamera0), keyEquivalent: "1"))
        cameraMenu.addItem(NSMenuItem(title: "Toggle Camera 1", action: #selector(toggleCamera1), keyEquivalent: "2"))
        cameraMenu.addItem(NSMenuItem(title: "Toggle Camera 2", action: #selector(toggleCamera2), keyEquivalent: "3"))
        cameraMenu.addItem(NSMenuItem(title: "Toggle Camera 3", action: #selector(toggleCamera3), keyEquivalent: "4"))
        cameraMenu.addItem(NSMenuItem.separator())
        cameraMenu.addItem(NSMenuItem(title: "Refresh Web View", action: #selector(refreshWebView), keyEquivalent: "r"))
        
        cameraMenuItem.submenu = cameraMenu
        mainMenu.addItem(cameraMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    @objc private func startAllStreams() {
        cameraViewController?.startAllStreams()
    }
    
    @objc private func stopAllStreams() {
        cameraViewController?.stopAllStreams()
    }
    
    @objc private func toggleCamera0() {
        cameraViewController?.toggleCamera(0)
    }
    
    @objc private func toggleCamera1() {
        cameraViewController?.toggleCamera(1)
    }
    
    @objc private func toggleCamera2() {
        cameraViewController?.toggleCamera(2)
    }
    
    @objc private func toggleCamera3() {
        cameraViewController?.toggleCamera(3)
    }
    
    @objc private func refreshWebView() {
        cameraViewController?.refreshWebView()
    }
}
