import UIKit
import Flutter
import Tealeaf

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Tealeaf code
    setenv("EODebug", "1", 1);
    setenv("TLF_DEBUG", "1", 1);
    let tlfApplicationHelperObj = TLFApplicationHelper()
    tlfApplicationHelperObj.enableTealeafFramework()
    //

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
