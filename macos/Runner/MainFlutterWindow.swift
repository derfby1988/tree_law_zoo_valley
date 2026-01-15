import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    
    // Set window size to iPhone 16e dimensions (375 x 812)
    let iPhoneWidth: CGFloat = 375
    let iPhoneHeight: CGFloat = 812
    self.setContentSize(NSSize(width: iPhoneWidth, height: iPhoneHeight))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
