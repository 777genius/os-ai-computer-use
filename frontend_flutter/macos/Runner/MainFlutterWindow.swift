import Cocoa
import FlutterMacOS

/// Container controller that wraps NSVisualEffectView (blur) + FlutterViewController.
/// NSWindow.contentViewController will own this, so the blur view stays as the root
/// and the Flutter view is layered on top with a transparent background.
class BlurContainerViewController: NSViewController {
  let flutterViewController = FlutterViewController()

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func loadView() {
    // NSVisualEffectView is the root view — provides macOS vibrancy blur
    let visualEffect = NSVisualEffectView()
    visualEffect.blendingMode = .behindWindow
    visualEffect.state = .active
    visualEffect.material = .hudWindow
    self.view = visualEffect

    // Add Flutter as a child controller
    addChild(flutterViewController)
    let flutterView = flutterViewController.view
    flutterView.translatesAutoresizingMaskIntoConstraints = false
    flutterView.wantsLayer = true
    flutterView.layer?.isOpaque = false
    flutterView.layer?.backgroundColor = NSColor.clear.cgColor
    if #available(macOS 10.13, *) {
      flutterViewController.backgroundColor = NSColor.clear
    }

    visualEffect.addSubview(flutterView)
    NSLayoutConstraint.activate([
      flutterView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
      flutterView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
      flutterView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
      flutterView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
    ])
  }
}

/// NSPanel subclass — allows floating over fullscreen apps via collectionBehavior.
/// NSPanel is a subclass of NSWindow, so all existing window functionality works.
class MainFlutterWindow: NSPanel {
  /// Saved frame for restoring after overlay mode
  private var savedFrame: NSRect?
  /// MethodChannel for communicating with Dart
  private var windowModeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let container = BlurContainerViewController()
    let windowFrame = self.frame
    self.contentViewController = container
    self.setFrame(windowFrame, display: true)

    // Window style: transparent titlebar with traffic lights inside the window
    self.styleMask.insert(.fullSizeContentView)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.isMovableByWindowBackground = true

    // Make the window transparent so the blur shows through
    self.isOpaque = false
    self.backgroundColor = NSColor.clear

    // Panel-specific: don't hide when app deactivates
    self.hidesOnDeactivate = false

    // Set up MethodChannel for window mode switching
    setupWindowModeChannel(messenger: container.flutterViewController.engine.binaryMessenger)

    RegisterGeneratedPlugins(registry: container.flutterViewController)

    super.awakeFromNib()
  }

  private func setupWindowModeChannel(messenger: FlutterBinaryMessenger) {
    windowModeChannel = FlutterMethodChannel(
      name: "com.osai/window_mode",
      binaryMessenger: messenger
    )

    windowModeChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { result(FlutterError(code: "UNAVAILABLE", message: "Window deallocated", details: nil)); return }

      switch call.method {
      case "enterOverlay":
        self.enterOverlayMode()
        result(true)
      case "exitOverlay":
        self.exitOverlayMode()
        result(true)
      case "isOverlay":
        let isOverlay = self.level.rawValue > NSWindow.Level.floating.rawValue
        result(isOverlay)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func enterOverlayMode() {
    // Save current frame for restoring later
    savedFrame = self.frame

    // Panel overlay properties
    self.level = .statusBar
    self.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
    ]
    self.isFloatingPanel = true
    self.styleMask.insert(.nonactivatingPanel)

    // Hide traffic light buttons in overlay mode
    self.standardWindowButton(.closeButton)?.isHidden = true
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true

    // Resize to compact size and position in bottom-right
    if let screen = self.screen ?? NSScreen.main {
      let overlayWidth: CGFloat = 380
      let overlayHeight: CGFloat = 520
      let padding: CGFloat = 20
      let newOrigin = NSPoint(
        x: screen.visibleFrame.maxX - overlayWidth - padding,
        y: screen.visibleFrame.minY + padding
      )
      let newFrame = NSRect(origin: newOrigin, size: NSSize(width: overlayWidth, height: overlayHeight))
      self.setFrame(newFrame, display: true, animate: true)
    }

    // Ensure minimum size in overlay mode
    self.minSize = NSSize(width: 300, height: 300)
  }

  private func exitOverlayMode() {
    // Restore normal window properties
    self.level = .normal
    self.collectionBehavior = []
    self.isFloatingPanel = false
    self.styleMask.remove(.nonactivatingPanel)

    // Show traffic light buttons
    self.standardWindowButton(.closeButton)?.isHidden = false
    self.standardWindowButton(.miniaturizeButton)?.isHidden = false
    self.standardWindowButton(.zoomButton)?.isHidden = false

    // Restore saved frame
    if let saved = savedFrame {
      self.setFrame(saved, display: true, animate: true)
    }

    // Reset minimum size
    self.minSize = NSSize(width: 600, height: 400)
  }
}
