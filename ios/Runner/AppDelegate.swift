import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    // Channel is registered but both methods are no-ops on iOS —
    // the UITextField layer trick caused black-screen crashes on iOS 16+.
    let channel = FlutterMethodChannel(
      name: "com.hessati/secure",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { _, result in
      result(nil) // no-op
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
