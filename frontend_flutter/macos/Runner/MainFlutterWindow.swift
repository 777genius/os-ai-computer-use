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

class MainFlutterWindow: NSWindow {
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

    RegisterGeneratedPlugins(registry: container.flutterViewController)

    super.awakeFromNib()
  }
}
