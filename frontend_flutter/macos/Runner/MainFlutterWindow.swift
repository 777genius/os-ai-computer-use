import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Make window background transparent
    self.isOpaque = false
    self.backgroundColor = NSColor.clear
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.isMovableByWindowBackground = true
    self.hasShadow = false
    self.contentView?.wantsLayer = true
    self.contentView?.layer?.isOpaque = false
    self.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.isOpaque = false
    flutterViewController.view.layer?.backgroundColor = NSColor.clear.cgColor
    if #available(macOS 10.13, *) {
      flutterViewController.backgroundColor = NSColor.clear
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
