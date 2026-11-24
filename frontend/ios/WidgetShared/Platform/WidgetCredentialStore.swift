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
    // Update in place: deleting first would leave a moment in which the
    // widget extension, reading at the same time, finds no credential.
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let updated = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
    if updated == errSecSuccess { return true }
    if updated != errSecItemNotFound {
      // Unreadable or stale item (for example one restored from another
      // device): replace it.
      SecItemDelete(baseQuery as CFDictionary)
    }
    var query = baseQuery
    query.merge(attributes) { _, new in new }
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
