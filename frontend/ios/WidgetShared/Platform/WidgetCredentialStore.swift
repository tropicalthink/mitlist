import Foundation
import Security

/// The widget credential in the Keychain, shared through the App Group's
/// access group (plan 047, contract C4). Never the app's login tokens.
public enum WidgetCredentialStore {
  private static var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: WidgetConstants.keychainService,
      kSecAttrAccount as String: WidgetConstants.keychainAccount,
      kSecAttrAccessGroup as String: WidgetConstants.appGroup,
    ]
  }

  /// Stores the credential JSON. Readable after the first unlock (Lock
  /// Screen widgets, background pushes) and never migrated to another
  /// device: the credential is bound to this install.
  @discardableResult
  public static func save(_ credential: WidgetCredential) -> Bool {
    guard let data = try? JSONEncoder().encode(credential) else { return false }
    SecItemDelete(baseQuery as CFDictionary)
    var query = baseQuery
    query[kSecValueData as String] = data
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
  }

  public static func load() -> WidgetCredential? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data
    else { return nil }
    return try? JSONDecoder().decode(WidgetCredential.self, from: data)
  }

  public static func delete() {
    SecItemDelete(baseQuery as CFDictionary)
  }
}
