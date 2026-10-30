import AuthenticationServices
import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let oauthLauncherChannelName = "mitlist/oauth_launcher"

  /// ASWebAuthenticationSession is deallocated — and the sheet dismissed — the
  /// moment nothing holds it, so the in-flight session has to outlive the call.
  private var authSession: ASWebAuthenticationSession?

  /// The app runs on the UIScene lifecycle (Info.plist `UIApplicationSceneManifest`):
  /// apps built with the iOS 27 SDK that don't adopt it are killed by UIKit at
  /// launch. The scene creates the FlutterViewController, and with it the
  /// engine, after `didFinishLaunching`, when the app delegate has no window
  /// yet, so plugins and app channels register here instead.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: oauthLauncherChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard call.method == "startAuthSession" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.startAuthSession(call: call, result: result)
    }

    // Home screen widgets, Siri and the shopping-trip Live Activity
    // (plan 047, contract C4).
    WidgetChannel.register(with: messenger)
  }

  /// The silent "widgets stale" push (plan 047, C6): ask every widget to
  /// refetch, then hand the message to FlutterFire through `super`, which
  /// calls the completion handler exactly once.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if userInfo["type"] as? String == "widget_refresh" {
      WidgetStorage.shared?.refreshRequested = true
      WidgetCenter.shared.reloadAllTimelines()
    }
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }

  /// Runs the provider sign-in inside the app as a sheet rather than handing the
  /// user off to Safari. The session also intercepts the `mitlist://` callback
  /// itself, so on iOS the deep link never has to make the round trip through
  /// the OS — the callback URL comes straight back through this channel.
  private func startAuthSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let urlString = args["url"] as? String,
      let url = URL(string: urlString),
      let callbackScheme = args["callbackScheme"] as? String,
      !callbackScheme.isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_url",
          message: "OAuth URL and callback scheme are required.",
          details: nil
        )
      )
      return
    }

    // The completion handler and the `start()` failure path can both try to
    // answer; a FlutterResult may only be called once.
    var didRespond = false
    let respond: (Any?) -> Void = { value in
      guard !didRespond else { return }
      didRespond = true
      result(value)
    }

    let session = ASWebAuthenticationSession(
      url: url,
      callbackURLScheme: callbackScheme
    ) { [weak self] callbackURL, error in
      self?.authSession = nil

      if let error = error {
        // Dismissing the sheet is a decision, not a failure: report it as "no
        // callback" so the caller quietly returns to the sign-in screen instead
        // of showing an error the user just caused on purpose.
        if let authError = error as? ASWebAuthenticationSessionError,
          authError.code == .canceledLogin
        {
          respond(nil)
          return
        }
        respond(
          FlutterError(
            code: "auth_session_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }

      respond(callbackURL?.absoluteString)
    }

    session.presentationContextProvider = self
    // Shared (non-ephemeral) so an existing Google/Apple web session signs the
    // user in with one tap instead of retyping credentials in a blank browser.
    session.prefersEphemeralWebBrowserSession = false

    authSession = session

    if !session.start() {
      authSession = nil
      respond(
        FlutterError(
          code: "launch_failed",
          message: "Could not open the sign-in sheet.",
          details: nil
        )
      )
    }
  }
}

extension AppDelegate: ASWebAuthenticationPresentationContextProviding {
  /// The Flutter view's window belongs to the window scene, not the app
  /// delegate, whose `window` stays nil under the scene lifecycle.
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    return scene?.keyWindow ?? scene?.windows.first ?? ASPresentationAnchor()
  }
}
