import Foundation
import Security
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  @MainActor
  func testDuoRegionObserverIsAttachedToFlutterView() throws {
    guard #available(iOS 27.1, *) else {
      throw XCTSkip("Requires iOS 27.1")
    }
    let flutterView = try XCTUnwrap(
      UIApplication.shared.connectedScenes
        .compactMap { $0.delegate as? SceneDelegate }
        .compactMap { $0.window?.rootViewController?.viewIfLoaded }
        .first
    )
    flutterView.layoutIfNeeded()
    let observer = try XCTUnwrap(
      flutterView.subviews.compactMap { $0 as? DuoRegionObserver }.first
    )
    XCTAssertEqual(observer.frame, flutterView.bounds)
    XCTAssertFalse(observer.isUserInteractionEnabled)
  }

  func testKeychainCanStoreAndReadToken() {
    let item: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "astralkeytest.runner-tests",
      kSecAttrAccount as String: UUID().uuidString,
      kSecAttrSynchronizable as String: false,
    ]
    let fixture = Data("fixture-token".utf8)
    var newItem = item
    newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
    newItem[kSecValueData as String] = fixture

    let addStatus = SecItemAdd(newItem as CFDictionary, nil)
    XCTAssertEqual(addStatus, errSecSuccess, "Runner could not write to Keychain")
    guard addStatus == errSecSuccess else { return }
    defer { SecItemDelete(item as CFDictionary) }

    var query = item
    query[kSecReturnData as String] = true
    var stored: CFTypeRef?
    let readStatus = SecItemCopyMatching(query as CFDictionary, &stored)
    XCTAssertEqual(readStatus, errSecSuccess, "Runner could not read from Keychain")
    XCTAssertEqual(stored as? Data, fixture)
  }

}
