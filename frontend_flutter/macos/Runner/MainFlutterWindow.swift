import Cocoa
import FlutterMacOS
import ObjectiveC

/// NSVisualEffectView that accepts first mouse click without requiring focus.
class FirstClickVisualEffectView: NSVisualEffectView {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    return true
  }
}

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
    let visualEffect = FirstClickVisualEffectView()
    visualEffect.blendingMode = .behindWindow
    visualEffect.state = .active
    visualEffect.material = .hudWindow
    self.view = visualEffect

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
/// First-click activation pattern from Multi.app / Raycast.
class MainFlutterWindow: NSPanel {
  private var savedFrame: NSRect?
  private var windowModeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let container = BlurContainerViewController()
    let windowFrame = self.frame
    self.contentViewController = container
    self.setFrame(windowFrame, display: true)

    self.styleMask.insert(.fullSizeContentView)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.isMovableByWindowBackground = true
    self.isOpaque = false
    self.backgroundColor = NSColor.clear
    self.hidesOnDeactivate = false
    self.acceptsMouseMovedEvents = true

    // Always become key on click, don't wait for text field
    self.becomesKeyOnlyIfNeeded = false

    // Swizzle FlutterViewWrapper to accept first mouse
    Self.swizzleFlutterViewWrapperIfNeeded()

    setupWindowModeChannel(messenger: container.flutterViewController.engine.binaryMessenger)
    RegisterGeneratedPlugins(registry: container.flutterViewController)

    super.awakeFromNib()
  }

  // Activate app when panel becomes key — the missing piece for first-click
  // Pattern from Multi.app: https://multi.app/blog/nailing-the-activation-behavior-of-a-spotlight-raycast-like-command-palette
  override func becomeKey() {
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    super.becomeKey()
  }

  // Intercept events before Flutter — make key + set first responder on click
  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown || event.type == .rightMouseDown {
      if !self.isKeyWindow {
        self.makeKey()
        if let flutterView = findFlutterView(in: self.contentView) {
          self.makeFirstResponder(flutterView)
        }
      }
    }
    super.sendEvent(event)
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  // Recursive search for FlutterView in hierarchy
  private func findFlutterView(in view: NSView?) -> NSView? {
    guard let view = view else { return nil }
    let className = String(describing: type(of: view))
    if className == "FlutterView" { return view }
    for subview in view.subviews {
      if let found = findFlutterView(in: subview) { return found }
    }
    return nil
  }

  // Swizzle FlutterViewWrapper.acceptsFirstMouse to return true
  private static var hasSwizzled = false
  private static func swizzleFlutterViewWrapperIfNeeded() {
    guard !hasSwizzled else { return }
    hasSwizzled = true

    guard let wrapperClass = NSClassFromString("FlutterViewWrapper") else { return }
    let selector = #selector(NSView.acceptsFirstMouse(for:))
    let implementation: @convention(c) (AnyObject, Selector, NSEvent?) -> Bool = { _, _, _ in
      return true
    }
    let imp = unsafeBitCast(implementation, to: IMP.self)
    let existingMethod = class_getInstanceMethod(wrapperClass, selector)
    if existingMethod == nil {
      class_addMethod(wrapperClass, selector, imp, "B@:@")
    } else {
      method_setImplementation(existingMethod!, imp)
    }
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
    savedFrame = self.frame

    self.level = .statusBar
    self.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
    ]
    self.isFloatingPanel = true
    self.styleMask.insert(.nonactivatingPanel)

    self.standardWindowButton(.closeButton)?.isHidden = true
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true

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

    self.minSize = NSSize(width: 300, height: 300)
  }

  private func exitOverlayMode() {
    self.level = .normal
    self.collectionBehavior = []
    self.isFloatingPanel = false
    self.styleMask.remove(.nonactivatingPanel)

    self.standardWindowButton(.closeButton)?.isHidden = false
    self.standardWindowButton(.miniaturizeButton)?.isHidden = false
    self.standardWindowButton(.zoomButton)?.isHidden = false

    if let saved = savedFrame {
      self.setFrame(saved, display: true, animate: true)
    }

    self.minSize = NSSize(width: 600, height: 400)
  }
}
