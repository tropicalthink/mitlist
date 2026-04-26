import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let oauthLauncherChannelName = "mitlist/oauth_launcher"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: oauthLauncherChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "launchExternalUrl" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let args = call.arguments as? [String: Any],
          let urlString = args["url"] as? String,
          let url = URL(string: urlString)
        else {
          result(
            FlutterError(
              code: "invalid_url",
              message: "OAuth URL is required.",
              details: nil
            )
          )
          return
        }

        UIApplication.shared.open(url, options: [:]) { success in
          if success {
            result(nil)
            return
          }

          result(
            FlutterError(
              code: "launch_failed",
              message: "No browser available to complete sign-in.",
              details: nil
            )
          )
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
