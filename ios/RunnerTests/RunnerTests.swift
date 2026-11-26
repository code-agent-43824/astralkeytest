import Foundation
import Security
import XCTest

class RunnerTests: XCTestCase {

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
