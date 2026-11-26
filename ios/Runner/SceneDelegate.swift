import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard #available(iOS 27.1, *),
      let controller = window?.rootViewController as? FlutterViewController
    else { return }

    let observer = DuoRegionObserver(
      frame: controller.view.bounds, messenger: controller.binaryMessenger
    )
    controller.view.addSubview(observer)
  }
}

@available(iOS 27.1, *)
final class DuoRegionObserver: UIView {
  private let channel: FlutterMethodChannel
  private var frames: [CGRect]?

  init(frame: CGRect, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.astralkey.astralkeytest/display_regions", binaryMessenger: messenger
    )
    super.init(frame: frame)
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    backgroundColor = .clear
    isOpaque = false
    isUserInteractionEnabled = false
    accessibilityElementsHidden = true

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "requestRegions" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.publishRegions()
      result(nil)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("Use init(frame:messenger:)")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // UIKit reruns layoutSubviews when the active regions reported here change.
    let currentFrames = reservedRegions(kind: .division).map(\.frame)
    guard frames != currentFrames else { return }
    frames = currentFrames
    publishRegions()
  }

  private func publishRegions() {
    let coordinates = (frames ?? []).map { [$0.minX, $0.minY, $0.maxX, $0.maxY] }
    channel.invokeMethod("regionsChanged", arguments: coordinates)
  }
}
