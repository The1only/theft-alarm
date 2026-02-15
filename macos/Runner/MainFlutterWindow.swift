import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    
    // Set minimum window size to show all content including connection status
    self.setContentSize(NSSize(width: 800, height: 800))
    self.minSize = NSSize(width: 600, height: 700)
    
    // Center window on screen
    self.center()
    
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}