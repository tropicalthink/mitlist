import AuthenticationServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let oauthLauncherChannelName = "mitlist/oauth_launcher"

  /// ASWebAuthenticationSession is deallocated — and the sheet dismissed — the
  /// moment nothing holds it, so the in-flight session has to outlive the call.
  private var authSession: ASWebAuthenticationSession?

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
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    return window ?? ASPresentationAnchor()
  }
}
