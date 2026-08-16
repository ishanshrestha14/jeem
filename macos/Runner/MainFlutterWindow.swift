import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // GymFlow is a phone app. The macOS build exists only to preview it while
    // the iOS simulator is unavailable, so size the window to an iPhone 16 Pro
    // logical viewport (393x852) rather than the desktop default. Without this
    // the layout is judged at a width the app will never actually run at.
    let phone = NSSize(width: 393, height: 852)
    var windowFrame = self.frame
    windowFrame.size = phone
    self.setFrame(windowFrame, display: true)
    self.contentMinSize = phone
    self.contentMaxSize = phone

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
