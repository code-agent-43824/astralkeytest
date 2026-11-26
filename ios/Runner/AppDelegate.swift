import AuthenticationServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var authSession: ASWebAuthenticationSession?
  private var authPresentation: AuthPresentation?
  private var authRequestID: UUID?
  private var authResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.astralkey.astralkeytest/oauth",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: nil, details: nil))
        return
      }
      switch call.method {
      case "authenticate":
        self.startAuthentication(call.arguments, result: result)
      case "cancel":
        let session = self.authSession
        self.finishAuthentication(nil)
        session?.cancel()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startAuthentication(_ arguments: Any?, result: @escaping FlutterResult) {
    guard authSession == nil else {
      result(FlutterError(code: "authentication_in_progress", message: nil, details: nil))
      return
    }
    guard let options = arguments as? [String: String],
      let rawURL = options["url"], let url = URL(string: rawURL), url.scheme == "https",
      let callbackScheme = options["callbackScheme"], !callbackScheme.isEmpty
    else {
      result(FlutterError(code: "invalid_authentication_url", message: nil, details: nil))
      return
    }
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .filter({ $0.activationState == .foregroundActive })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow })
    else {
      result(FlutterError(code: "missing_presentation_window", message: nil, details: nil))
      return
    }

    let requestID = UUID()
    let presentation = AuthPresentation(window: window)
    let session = ASWebAuthenticationSession(
      url: url, callbackURLScheme: callbackScheme
    ) { [weak self] callback, error in
      DispatchQueue.main.async {
        guard let self = self, self.authRequestID == requestID else { return }
        if let callback = callback {
          self.finishAuthentication(callback.absoluteString)
        } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
          self.finishAuthentication(nil)
        } else {
          self.finishAuthentication(
            FlutterError(code: "authentication_failed", message: nil, details: nil)
          )
        }
      }
    }
    session.presentationContextProvider = presentation
    authPresentation = presentation
    authSession = session
    authRequestID = requestID
    authResult = result
    if !session.start() {
      finishAuthentication(FlutterError(code: "cannot_start_authentication", message: nil, details: nil))
    }
  }

  private func finishAuthentication(_ value: Any?) {
    let pending = authResult
    authResult = nil
    authRequestID = nil
    authSession = nil
    authPresentation = nil
    pending?(value)
  }
}

private final class AuthPresentation: NSObject, ASWebAuthenticationPresentationContextProviding {
  private let window: UIWindow

  init(window: UIWindow) {
    self.window = window
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    window
  }
}
