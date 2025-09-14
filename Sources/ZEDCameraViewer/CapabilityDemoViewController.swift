import AppKit
import SceneKit
import Foundation

final class CapabilityDemoViewController: NSViewController {
	private var backgroundView: NSView!
	private var sceneView: SCNView!
	private var scene: SCNScene!
	private var cameraNode: SCNNode!
	private var pacmanNode: SCNNode!
	private var fiberCableNode: SCNNode!
	private var currentIndex: Int = 0
	private var labelNodes: [SCNNode] = []
	private var eventMonitor: Any?
	private var lastLayoutSize: CGSize = .zero

	// Six camera angles (5 capability views + 1 fiber cable view)
	private let cameraSettings: [(position: SCNVector3, lookAt: SCNVector3, zoom: Float)] = [
		(SCNVector3(0, 0, 8), SCNVector3(0, 0, 0), 1.0),
		(SCNVector3(2, 1, 4), SCNVector3(0, 0, 0), 2.0),
		(SCNVector3(4, 1, -2), SCNVector3(0, 0, 0), 1.6),
		(SCNVector3(0, 8, 0), SCNVector3(0, 0, 0), 1.0),
		(SCNVector3(-2, 1, 4), SCNVector3(0, 0, 0), 2.0),
		(SCNVector3(-3, -15, -3), SCNVector3(0, 0, 0), 0.5)  // Diagonal bird's eye with wider zoom
	]

	// All 10 capabilities + fiber cable view (Hebrew, clean formatting)
	private let capabilityPairs: [[String]] = [
		[
			"תבוסה תת־קרקעית\nקצב קריסה ~1 מטר לדקה",
			"פריצת קשת\nפריצה מאומתת של ציפויי מנהרות/קשתות"
		],
		[
			"תמרון במרחב מצומצם\nפניות של 45° במעברים ברוחב ~70 ס\"מ",
			"התמודדות עם שיפוע/מדרגות\nעלייה וירידה בזווית עד 30°"
		],
		[
			"הפחתת מכשולים\nפינוי עפר, הריסות ושברי בטון\nעד ~20 ס\"מ אובייקט דחוס מלופף",
			"שליטה ובקרה מרחוק\nשליטה מלאה ב-PC/VR עם וידאו בזמן אמת\nהשהייה זניחה"
		],
		[
			"טווח פעולה\nעד 250 מטר כבל טבורי מבצעי",
			"מפת עומק מנהרה בזמן אמת\nהצגת עומק מנהרה בזמן אמת למפעיל"
		],
		[
			"איתור בסביבה נטולת PNT\nמעקב ויזואלי-אינרציאלי במנהרות ללא GPS",
			"איסוף מודיעין אקוסטי\nניטור שמע מובנה (שמיעה בתוך המנהרה)"
		],
		[
			"סיב אופטי\nתקשורת רציפה. השהייה אפסית",
			""  // Single text for fiber cable view
		]
	]

	override func loadView() {
		view = NSView()
		setupUI()
		setup3DScene()
	}

	override func viewDidAppear() {
		super.viewDidAppear()
		installKeyMonitor()
	}

	override func viewWillDisappear() {
		super.viewWillDisappear()
		removeKeyMonitor()
	}

	override func viewDidLayout() {
		super.viewDidLayout()
		let size = sceneView?.bounds.size ?? .zero
		if size.width > 1 && size.height > 1 && size != lastLayoutSize {
			lastLayoutSize = size
			if !labelNodes.isEmpty { updateCapabilityLabels() }
		}
	}

	private func setupUI() {
		view.wantsLayer = true
		// Background gradient
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

		// Scene view full-bleed with margin
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
		view.addSubview(sceneView)

		NSLayoutConstraint.activate([
			backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
			backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

			sceneView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
			sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
			sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
			sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
		])
	}

	private func setup3DScene() {
		scene = SCNScene()

		// Load pacman model (same strategy as SystemsCheck)
		var modelURL: URL?
		let directPath = "/Users/yadinsoffer/Desktop/Twelve/Sources/ZEDCameraViewer/pacman0.usdc"
		if FileManager.default.fileExists(atPath: directPath) {
			modelURL = URL(fileURLWithPath: directPath)
		} else if let bundleURL = Bundle.module.url(forResource: "pacman0", withExtension: "usdc") {
			modelURL = bundleURL
		} else if let mainURL = Bundle.main.url(forResource: "pacman0", withExtension: "usdc") {
			modelURL = mainURL
		}

		if let url = modelURL, let modelScene = try? SCNScene(url: url, options: nil) {
			var foundNode: SCNNode?
			for child in modelScene.rootNode.childNodes {
				if child.geometry != nil { foundNode = child; break }
				for grand in child.childNodes { if grand.geometry != nil { foundNode = grand; break } }
				if foundNode != nil { break }
			}
			if foundNode == nil, let first = modelScene.rootNode.childNodes.first { foundNode = first }
			if let modelNode = foundNode {
				pacmanNode = modelNode.clone()
				pacmanNode.position = SCNVector3(0, -1.0, 0)
				pacmanNode.scale = SCNVector3(0.022, 0.022, 0.022)
				pacmanNode.eulerAngles = SCNVector3(-Float.pi/2, -Float.pi/2 + 0.3, 0)
				scene.rootNode.addChildNode(pacmanNode)
			} else {
				createFallbackGeometry()
			}
		} else {
			createFallbackGeometry()
		}

		// Camera
		cameraNode = SCNNode()
		cameraNode.camera = SCNCamera()
		cameraNode.camera?.fieldOfView = 60
		scene.rootNode.addChildNode(cameraNode)

		// Grid and lighting (reuse look)
		addGrid()
		setupLighting()

		sceneView.scene = scene
		sceneView.pointOfView = cameraNode

		// Load fiber cable model for 6th view
		loadFiberCableModel()
		
		// Initial view
		applyCurrentCamera(animated: false)
		updateCapabilityLabels()
	}

	private func addGrid() {
		let gridContainer = SCNNode()
		let floor = createGridPlane(width: 50, height: 50, divisions: 50)
		floor.position = SCNVector3(0, -4, 0)
		floor.eulerAngles = SCNVector3(-Float.pi/2, 0, 0)
		gridContainer.addChildNode(floor)
		let back = createGridPlane(width: 50, height: 30, divisions: 50)
		back.position = SCNVector3(0, 11, -25)
		gridContainer.addChildNode(back)
		let right = createGridPlane(width: 50, height: 30, divisions: 50)
		right.position = SCNVector3(25, 11, 0)
		right.eulerAngles = SCNVector3(0, Float.pi/2, 0)
		gridContainer.addChildNode(right)
		let left = createGridPlane(width: 50, height: 30, divisions: 50)
		left.position = SCNVector3(-25, 11, 0)
		left.eulerAngles = SCNVector3(0, -Float.pi/2, 0)
		gridContainer.addChildNode(left)
		scene.rootNode.addChildNode(gridContainer)
	}

	private func createGridPlane(width: Float, height: Float, divisions: Int) -> SCNNode {
		let plane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
		let node = SCNNode(geometry: plane)
		let material = SCNMaterial()
		material.fillMode = .lines
		material.diffuse.contents = NSColor(white: 0.3, alpha: 0.4)
		material.lightingModel = .constant
		material.isDoubleSided = true
		plane.materials = [material]
		plane.widthSegmentCount = divisions
		plane.heightSegmentCount = Int(Float(divisions) * height / width)
		return node
	}

	private func setupLighting() {
		let ambient = SCNNode()
		ambient.light = SCNLight()
		ambient.light?.type = .ambient
		ambient.light?.color = NSColor(white: 0.2, alpha: 1.0)
		scene.rootNode.addChildNode(ambient)
		let key = SCNNode()
		key.light = SCNLight()
		key.light?.type = .directional
		key.light?.color = NSColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
		key.light?.intensity = 800
		key.position = SCNVector3(5, 8, 5)
		key.look(at: SCNVector3(0, 0, 0))
		scene.rootNode.addChildNode(key)
		let rim = SCNNode()
		rim.light = SCNLight()
		rim.light?.type = .spot
		rim.light?.color = NSColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0)
		rim.light?.intensity = 500
		rim.light?.spotInnerAngle = 30
		rim.light?.spotOuterAngle = 80
		rim.position = SCNVector3(-3, 2, -5)
		rim.look(at: SCNVector3(0, 0, 0))
		scene.rootNode.addChildNode(rim)
		let fill = SCNNode()
		fill.light = SCNLight()
		fill.light?.type = .omni
		fill.light?.color = NSColor(white: 0.6, alpha: 1.0)
		fill.light?.intensity = 200
		fill.position = SCNVector3(0, -2, 0)
		scene.rootNode.addChildNode(fill)
	}

	private func createFallbackGeometry() {
		let geometry = SCNBox(width: 2.0, height: 2.0, length: 2.0, chamferRadius: 0.1)
		let material = SCNMaterial()
		material.diffuse.contents = NSColor.white
		material.fillMode = .lines
		material.lightingModel = .constant
		geometry.materials = [material]
		pacmanNode = SCNNode(geometry: geometry)
		pacmanNode.position = SCNVector3(0, 0, 0)
		scene.rootNode.addChildNode(pacmanNode)
		let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 4.0)
		pacmanNode.runAction(.repeatForever(rotate))
	}

	private func applyCurrentCamera(animated: Bool) {
		let setting = cameraSettings[currentIndex]
		SCNTransaction.begin()
		SCNTransaction.animationDuration = animated ? 1.2 : 0.0
		SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
		SCNTransaction.completionBlock = { [weak self] in
			self?.updateCapabilityLabels()
		}
		cameraNode.transform = SCNMatrix4Identity
		cameraNode.position = setting.position
		cameraNode.look(at: setting.lookAt)
		let baseFOV: Float = 60.0
		cameraNode.camera?.fieldOfView = CGFloat(baseFOV / max(setting.zoom, 0.1))
		SCNTransaction.commit()
	}

	private func updateCapabilityLabels() {
		// Ensure we have a real drawable size
		guard sceneView.bounds.width > 1 && sceneView.bounds.height > 1 else { return }
		// Remove previous labels
		for node in labelNodes { node.removeFromParentNode() }
		labelNodes.removeAll()

		let pair = capabilityPairs[currentIndex]
		// Use the currently visible model (pacman or fiber cable)
		let activeNode = (currentIndex == 5) ? fiberCableNode : pacmanNode
		guard let activeNode = activeNode else { return }
		let bbox = activeNode.boundingBox
		let localSize = SCNVector3(bbox.max.x - bbox.min.x, bbox.max.y - bbox.min.y, bbox.max.z - bbox.min.z)
		let localCenter = SCNVector3((bbox.min.x + bbox.max.x) / 2.0, (bbox.min.y + bbox.max.y) / 2.0, (bbox.min.z + bbox.max.z) / 2.0)
		let scale = activeNode.presentation.scale
		let sizeWorld = SCNVector3(localSize.x * scale.x, localSize.y * scale.y, localSize.z * scale.z)
		let centerWorld = activeNode.presentation.convertPosition(localCenter, to: nil)

		// Build screen-rect of the device by projecting 8 bbox corners
		let mins = bbox.min, maxs = bbox.max
		let cornersLocal: [SCNVector3] = [
			SCNVector3(mins.x, mins.y, mins.z), SCNVector3(maxs.x, mins.y, mins.z),
			SCNVector3(mins.x, maxs.y, mins.z), SCNVector3(maxs.x, maxs.y, mins.z),
			SCNVector3(mins.x, mins.y, maxs.z), SCNVector3(maxs.x, mins.y, maxs.z),
			SCNVector3(mins.x, maxs.y, maxs.z), SCNVector3(maxs.x, maxs.y, maxs.z)
		]
		var minX = CGFloat.greatestFiniteMagnitude
		var minY = CGFloat.greatestFiniteMagnitude
		var maxX: CGFloat = 0
		var maxY: CGFloat = 0
		var depthZ: Float = 0
		for c in cornersLocal {
			let cw = activeNode.presentation.convertPosition(c, to: nil)
			let p = sceneView.projectPoint(cw)
			minX = min(minX, CGFloat(p.x)); minY = min(minY, CGFloat(p.y))
			maxX = max(maxX, CGFloat(p.x)); maxY = max(maxY, CGFloat(p.y))
			depthZ += Float(p.z)
		}
		// Prefer center depth for stability
		let centerProj = sceneView.projectPoint(centerWorld)
		depthZ = Float(centerProj.z)
		let deviceRect = CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))

		let bounds = sceneView.bounds
		let margin: CGFloat = 30
		let gapPx: CGFloat = 20
		let slotGapPx: CGFloat = 80
		let maxWidthPxDefault: CGFloat = 520

		let rightSpace = bounds.maxX - deviceRect.maxX - margin
		let leftSpace = deviceRect.minX - margin
		var placeRight = rightSpace >= leftSpace
		
		// Force right side for all views - use the clear space
		placeRight = true
		// Compute max available pixel width on chosen side
		func availableWidthPx(onRight: Bool) -> CGFloat {
			if onRight { return max(0, bounds.maxX - (deviceRect.maxX + gapPx) - margin) }
			else { return max(0, (deviceRect.minX - gapPx) - margin) }
		}

		func buildImage(for text: String, maxWidthPx: CGFloat) -> (NSImage, CGSize) {
			// Parse title and subtitle from text (separated by first newline)
			let lines = text.components(separatedBy: "\n")
			let titleLine = lines.first ?? text
			let subtitleLines = Array(lines.dropFirst())
			
			// Title font (larger, bold)
			let titleFont = NSFont(name: "SF Hebrew", size: 32) ?? NSFont.systemFont(ofSize: 32, weight: .bold)
			// Subtitle font (smaller, regular)
			let subtitleFont = NSFont(name: "SF Hebrew", size: 20) ?? NSFont.systemFont(ofSize: 20, weight: .medium)
			
			let paragraph = NSMutableParagraphStyle()
			paragraph.alignment = .right
			paragraph.baseWritingDirection = .rightToLeft
			paragraph.lineSpacing = 4
			
			let titleAttrs: [NSAttributedString.Key: Any] = [
				.font: titleFont,
				.foregroundColor: NSColor.white,
				.paragraphStyle: paragraph
			]
			let subtitleAttrs: [NSAttributedString.Key: Any] = [
				.font: subtitleFont,
				.foregroundColor: NSColor(white: 0.85, alpha: 1.0),
				.paragraphStyle: paragraph
			]
			
			// Build attributed string with icon + title + subtitle styling
			let attributed = NSMutableAttributedString()
			
			// No icons - clean text only
			
			attributed.append(NSAttributedString(string: titleLine, attributes: titleAttrs))
			if !subtitleLines.isEmpty {
				attributed.append(NSAttributedString(string: "\n", attributes: titleAttrs))
				for (i, line) in subtitleLines.enumerated() {
					if i > 0 { attributed.append(NSAttributedString(string: "\n", attributes: subtitleAttrs)) }
					attributed.append(NSAttributedString(string: line, attributes: subtitleAttrs))
				}
			}
			
			let padding: CGFloat = 20
			var bounds = attributed.boundingRect(with: NSSize(width: maxWidthPx, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
			bounds.size.width = min(maxWidthPx, ceil(bounds.size.width))
			bounds.size.height = ceil(bounds.size.height)
			let imgSize = NSSize(width: bounds.size.width + padding * 2, height: bounds.size.height + padding * 2)
			let image = NSImage(size: imgSize)
			image.lockFocus()
			
			// Rounded background with subtle gradient
			let rect = NSRect(origin: .zero, size: imgSize)
			let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
			NSColor(white: 0.0, alpha: 0.7).setFill()
			path.fill()
			
			// Add subtle border
			NSColor(white: 0.3, alpha: 0.5).setStroke()
			path.lineWidth = 1.5
			path.stroke()
			
			attributed.draw(with: NSRect(x: padding, y: padding, width: bounds.size.width, height: bounds.size.height), options: [.usesLineFragmentOrigin, .usesFontLeading])
			image.unlockFocus()
			return (image, imgSize)
		}

		// Debug: print current view info
		print("View \(currentIndex): deviceRect=\(deviceRect), bounds=\(bounds)")
		print("rightSpace=\(rightSpace), leftSpace=\(leftSpace), placeRight=\(placeRight)")
		
		// Prepare label images and positions (filter out empty strings)
		let texts = pair.filter { !$0.isEmpty }
		// Position labels in bottom-right area for better visibility
		let bottomY = bounds.maxY * 0.25  // Bottom quarter of screen
		var slotYs: [CGFloat]
		if texts.count == 1 {
			// Single label for fiber cable view - center it
			slotYs = [bottomY]
		} else {
			slotYs = [bottomY + 60, bottomY - 60]
		}
		var nodes: [SCNNode] = []
		for (idx, text) in texts.enumerated() {
			// Build image (auto-wrap)
			let initialMax = min(maxWidthPxDefault, max(380, availableWidthPx(onRight: placeRight)))
			var (image, imgSize) = buildImage(for: text, maxWidthPx: initialMax)
			// Ensure it fits vertically; if not, shrink width to reduce height
			var attempt = 0
			while attempt < 3 {
				let halfH = imgSize.height / 2
				let clampedY = min(max(slotYs[idx], margin + halfH), bounds.maxY - margin - halfH)
				slotYs[idx] = clampedY
				let halfW = imgSize.width / 2
				let desiredCenterX: CGFloat
				if placeRight {
					let candidate = deviceRect.maxX + gapPx + halfW
					desiredCenterX = min(max(candidate, margin + halfW), bounds.maxX - margin - halfW)
				} else {
					let candidate = deviceRect.minX - gapPx - halfW
					desiredCenterX = max(min(candidate, bounds.maxX - margin - halfW), margin + halfW)
				}
				// If it still collides with device rect horizontally or exceeds side space, reduce width and retry
				let overlapsDeviceHorizontally = placeRight ? (desiredCenterX - halfW < deviceRect.maxX + gapPx) : (desiredCenterX + halfW > deviceRect.minX - gapPx)
				let sideSpace = availableWidthPx(onRight: placeRight)
				let tooWideForSide = imgSize.width > sideSpace
				if (overlapsDeviceHorizontally || tooWideForSide) && imgSize.width > 380 {
					let nextWidth = max(380, min(imgSize.width - 120, sideSpace))
					(image, imgSize) = buildImage(for: text, maxWidthPx: nextWidth)
					attempt += 1
					continue
				}
				// Compute world center from screen center
				let screenCenter = SCNVector3(Float(desiredCenterX), Float(slotYs[idx]), depthZ)
				let worldCenter = sceneView.unprojectPoint(screenCenter)
				// Compute world width from pixel width
				let p0 = sceneView.unprojectPoint(SCNVector3(Float(desiredCenterX - halfW), Float(slotYs[idx]), depthZ))
				let p1 = sceneView.unprojectPoint(SCNVector3(Float(desiredCenterX + halfW), Float(slotYs[idx]), depthZ))
				var worldW = vecLength(vecSub(p1, p0))
				// Conservative fallback if invalid
				if !worldW.isFinite || worldW <= 0 { worldW = 0.5 }
				// Build plane node
				let aspect = imgSize.width / imgSize.height
				let plane = SCNPlane(width: CGFloat(worldW), height: CGFloat(worldW) / aspect)
				let material = SCNMaterial()
				material.diffuse.contents = image
				material.isDoubleSided = true
				material.writesToDepthBuffer = false
				material.readsFromDepthBuffer = false
				material.lightingModel = .constant
				plane.materials = [material]
				let node = SCNNode(geometry: plane)
				let billboard = SCNBillboardConstraint()
				billboard.freeAxes = [.X, .Y, .Z]
				node.constraints = [billboard]
				node.position = worldCenter
				node.opacity = 0.0
				scene.rootNode.addChildNode(node)
				node.runAction(SCNAction.fadeIn(duration: 0.25))
				nodes.append(node)
				break
			}
			// If placement failed after attempts, flip side once and try again
			if attempt >= 3 && nodes.count <= idx {
				placeRight.toggle()
				attempt = 0
				continue
			}
		}

		labelNodes.append(contentsOf: nodes)
	}

	private func makeBillboardLabel(text: String, worldWidth: CGFloat) -> SCNNode {
		let font = NSFont(name: "SF Hebrew", size: 28) ?? NSFont.systemFont(ofSize: 28, weight: .semibold)
		let paragraph = NSMutableParagraphStyle()
		paragraph.alignment = .right
		paragraph.baseWritingDirection = .rightToLeft
		let attrs: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: NSColor.white,
			.paragraphStyle: paragraph
		]
		let maxWidth: CGFloat = 800
		let padding: CGFloat = 18
		let attributed = NSAttributedString(string: text, attributes: attrs)
		var bounds = attributed.boundingRect(with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
		bounds.size.width = min(maxWidth, ceil(bounds.size.width))
		bounds.size.height = ceil(bounds.size.height)
		let imgSize = NSSize(width: bounds.size.width + padding * 2, height: bounds.size.height + padding * 2)
		let image = NSImage(size: imgSize)
		image.lockFocus()
		NSColor(white: 0.0, alpha: 0.55).setFill()
		let rect = NSRect(origin: .zero, size: imgSize)
		let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
		path.fill()
		attributed.draw(with: NSRect(x: padding, y: padding, width: bounds.size.width, height: bounds.size.height), options: [.usesLineFragmentOrigin, .usesFontLeading])
		image.unlockFocus()
		let aspect = imgSize.width / imgSize.height
		let plane = SCNPlane(width: worldWidth, height: worldWidth / aspect)
		let material = SCNMaterial()
		material.diffuse.contents = image
		material.isDoubleSided = true
		material.writesToDepthBuffer = false
		material.readsFromDepthBuffer = false
		material.lightingModel = .constant
		plane.materials = [material]
		let node = SCNNode(geometry: plane)
		let billboard = SCNBillboardConstraint()
		billboard.freeAxes = .Y
		node.constraints = [billboard]
		return node
	}

	private func installKeyMonitor() {
		guard eventMonitor == nil else { return }
		eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
			guard let self else { return event }
			// Spacebar keyCode is 49
			if event.keyCode == 49 {
				self.advance()
				return nil
			}
			return event
		}
	}

	private func removeKeyMonitor() {
		if let monitor = eventMonitor {
			NSEvent.removeMonitor(monitor)
			eventMonitor = nil
		}
	}

	private func loadFiberCableModel() {
		let directPath = "/Users/yadinsoffer/Desktop/Twelve/Sources/ZEDCameraViewer/Custom_5G_Fiber_Cable.usdz"
		guard FileManager.default.fileExists(atPath: directPath),
			  let url = URL(string: "file://" + directPath),
			  let modelScene = try? SCNScene(url: url, options: nil) else {
			print("Could not load Custom_5G_Fiber_Cable.usdz")
			return
		}
		
		var foundNode: SCNNode?
		for child in modelScene.rootNode.childNodes {
			if child.geometry != nil { foundNode = child; break }
			for grand in child.childNodes { if grand.geometry != nil { foundNode = grand; break } }
			if foundNode != nil { break }
		}
		if foundNode == nil, let first = modelScene.rootNode.childNodes.first { foundNode = first }
		
		if let modelNode = foundNode {
			fiberCableNode = modelNode.clone()
			fiberCableNode.position = SCNVector3(0, -1.0, 0)
			fiberCableNode.scale = SCNVector3(0.022, 0.022, 0.022)
			fiberCableNode.eulerAngles = SCNVector3(0, 0, 0)  // Keep upright, no rotation
			fiberCableNode.isHidden = true  // Hidden initially
			scene.rootNode.addChildNode(fiberCableNode)
		}
	}

	private func advance() {
		currentIndex = (currentIndex + 1) % cameraSettings.count
		
		// Switch models for 6th view (fiber cable)
		if currentIndex == 5 {
			pacmanNode?.isHidden = true
			fiberCableNode?.isHidden = false
		} else {
			pacmanNode?.isHidden = false
			fiberCableNode?.isHidden = true
		}
		
		applyCurrentCamera(animated: true)
	}
}

// MARK: - SCNVector3 helpers
private func vecAdd(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
	return SCNVector3(a.x + b.x, a.y + b.y, a.z + b.z)
}

private func vecSub(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
	return SCNVector3(a.x - b.x, a.y - b.y, a.z - b.z)
}

private func vecMul(_ v: SCNVector3, _ s: CGFloat) -> SCNVector3 {
	return SCNVector3(v.x * s, v.y * s, v.z * s)
}

private func vecLength(_ v: SCNVector3) -> CGFloat {
	return (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
}

private func vecNormalize(_ v: SCNVector3) -> SCNVector3 {
	let l = vecLength(v)
	guard l > 0 else { return SCNVector3(0, 0, 0) }
	return SCNVector3(v.x / l, v.y / l, v.z / l)
}

private func vecCross(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
	return SCNVector3(
		a.y * b.z - a.z * b.y,
		a.z * b.x - a.x * b.z,
		a.x * b.y - a.y * b.x
	)
}


