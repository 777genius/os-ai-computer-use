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
  private var hotkeyChannel: FlutterMethodChannel?
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?

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
    setupPermissionsChannel(messenger: container.flutterViewController.engine.binaryMessenger)
    hotkeyChannel = FlutterMethodChannel(
      name: "com.osai/hotkeys",
      binaryMessenger: container.flutterViewController.engine.binaryMessenger
    )
    RegisterGeneratedPlugins(registry: container.flutterViewController)

    // Request Accessibility permission (shows system prompt if not granted)
    let trusted = AXIsProcessTrustedWithOptions(
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    )
    NSLog("Accessibility permission: %@", trusted ? "granted" : "not granted (prompt shown)")

    setupGlobalHotkeys()

    super.awakeFromNib()
  }

  override func becomeKey() {
    super.becomeKey()
  }

  override func resignKey() {
    super.resignKey()
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

  /// Register global Ctrl+Esc hotkey via CGEventTap.
  /// Apple-recommended approach (over Carbon RegisterEventHotKey and NSEvent monitors).
  /// Works in both debug and release builds. Requires Accessibility/Input Monitoring permission.
  /// Reference: https://developer.apple.com/forums/thread/735223
  private func setupGlobalHotkeys() {
    // Request Input Monitoring permission (macOS 10.15+)
    if #available(macOS 10.15, *) {
      let hasAccess = CGPreflightListenEventAccess()
      if !hasAccess {
        NSLog("Input Monitoring not granted, requesting...")
        CGRequestListenEventAccess()
      }
    }

    // Store a weak reference for use in C callback
    let refcon = Unmanaged.passUnretained(self).toOpaque()

    // CGEventTap callback — C function, no captures allowed
    let callback: CGEventTapCallBack = { proxy, type, event, refcon in
      // Handle tap disabled by timeout — re-enable
      if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon = refcon {
          let panel = Unmanaged<MainFlutterWindow>.fromOpaque(refcon).takeUnretainedValue()
          if let tap = panel.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            NSLog("CGEventTap re-enabled after timeout")
          }
        }
        return Unmanaged.passUnretained(event)
      }

      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      let flags = event.flags

      // Ctrl+Esc: keyCode 53, Control flag only
      if keyCode == 53 && flags.contains(.maskControl) &&
         !flags.contains(.maskShift) && !flags.contains(.maskCommand) && !flags.contains(.maskAlternate) {
        NSLog("Global hotkey Ctrl+Esc triggered via CGEventTap")
        if let refcon = refcon {
          let panel = Unmanaged<MainFlutterWindow>.fromOpaque(refcon).takeUnretainedValue()
          DispatchQueue.main.async { [weak panel] in
            guard let channel = panel?.hotkeyChannel else {
              NSLog("hotkeyChannel is nil, skipping emergencyStop")
              return
            }
            channel.invokeMethod("emergencyStop", arguments: nil) { result in
              if let error = result as? FlutterError {
                NSLog("emergencyStop error: %@", error.message ?? "unknown")
              }
            }
          }
        }
        // Swallow the event (don't pass to active app)
        return nil
      }

      return Unmanaged.passUnretained(event)
    }

    // Create the tap — listen for keyDown events globally
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
      callback: callback,
      userInfo: refcon
    ) else {
      NSLog("Failed to create CGEventTap — check Accessibility/Input Monitoring permission")
      return
    }

    eventTap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    if let source = runLoopSource {
      CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    }
    CGEvent.tapEnable(tap: tap, enable: true)
    NSLog("CGEventTap registered for Ctrl+Esc (global hotkey)")
  }

  override func close() {
    teardownGlobalHotkeys()
    super.close()
  }

  private func teardownGlobalHotkeys() {
    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
      eventTap = nil
    }
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
      runLoopSource = nil
    }
  }

  private func setupPermissionsChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.osai/permissions", binaryMessenger: messenger)
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "checkAccessibility":
        let trusted = AXIsProcessTrustedWithOptions(nil)
        result(trusted)
      case "requestAccessibility":
        let trusted = AXIsProcessTrustedWithOptions(
          [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        result(trusted)
      case "checkScreenRecording":
        if #available(macOS 10.15, *) {
          result(CGPreflightScreenCaptureAccess())
        } else {
          result(true)
        }
      case "requestScreenRecording":
        if #available(macOS 10.15, *) {
          CGRequestScreenCaptureAccess()
        }
        result(nil)
      case "checkInputMonitoring":
        if #available(macOS 10.15, *) {
          result(CGPreflightListenEventAccess())
        } else {
          result(true)
        }
      case "requestInputMonitoring":
        if #available(macOS 10.15, *) {
          CGRequestListenEventAccess()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
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
