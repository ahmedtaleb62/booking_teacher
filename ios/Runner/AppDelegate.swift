import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var secureTextField: UITextField?
  private var originalSuperLayer: CALayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.hessati/secure",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "enable":
        self.enableSecure()
        result(nil)
      case "disable":
        self.disableSecure()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // The UITextField isSecureTextEntry layer trick:
  // Moving the window's layer to be a sublayer of the secure text field's layer
  // causes iOS to treat the entire window as protected content (appears black in screenshots).
  private func enableSecure() {
    guard secureTextField == nil,
          let window = UIApplication.shared.windows.first else { return }

    let field = UITextField()
    field.isSecureTextEntry = true
    window.addSubview(field)

    originalSuperLayer = window.layer.superlayer
    window.layer.superlayer?.addSublayer(field.layer)
    field.layer.sublayers?.last?.addSublayer(window.layer)

    secureTextField = field
  }

  private func disableSecure() {
    guard let field = secureTextField,
          let window = UIApplication.shared.windows.first else { return }

    // Restore window layer to the screen layer
    if let screenLayer = UIApplication.shared.windows.first?.screen.value(forKey: "displayLayer") as? CALayer {
      screenLayer.addSublayer(window.layer)
    } else {
      // Fallback: re-add to the original superlayer
      originalSuperLayer?.addSublayer(window.layer)
    }

    field.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    field.removeFromSuperview()
    secureTextField = nil
    originalSuperLayer = nil
  }
}
