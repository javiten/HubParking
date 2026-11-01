import SwiftUI
import LocalAuthentication
import Security

@MainActor
class UserManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var showLoginError = false
    @Published var biometricError: String?
    @Published var biometricBusy = false
    @Published var biometricEnabled = UserDefaults.standard.bool(forKey: "hubBiometricEnabled")
    var shouldAutoAuthenticate = true
    private let service = "com.hubparking.biometric-login"
    private let account = "linked-user"

    var biometricName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType == .touchID ? "Touch ID" : "Face ID"
    }
    var biometricAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func authenticate(pin: String, enableBiometrics: Bool = false) {
        guard !pin.isEmpty, let user = User.authorizedUsers.first(where: { $0.pin == pin }) else {
            showLoginError = true
            return
        }
        biometricError = nil
        if enableBiometrics {
            do { try linkBiometrics(user) }
            catch {
                biometricError = "Could not enable \(biometricName). Try again or turn off the option to sign in with PIN."
                return
            }
        }
        currentUser = user
        UserDefaults.standard.set(user.name, forKey: "currentUser")
        isAuthenticated = true
        showLoginError = false
    }

    private func linkBiometrics(_ user: User) throws {
        guard biometricAvailable,
              let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, nil) else {
            throw NSError(domain: "HubBiometrics", code: 1)
        }
        let identity: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account]
        let deleted = SecItemDelete(identity as CFDictionary)
        guard deleted == errSecSuccess || deleted == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(deleted))
        }
        biometricEnabled = false
        UserDefaults.standard.set(false, forKey: "hubBiometricEnabled")
        var item = identity
        item[kSecAttrAccessControl as String] = access
        item[kSecValueData as String] = Data(user.id.uuidString.utf8)
        let result = SecItemAdd(item as CFDictionary, nil)
        guard result == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(result)) }
        biometricEnabled = true
        UserDefaults.standard.set(true, forKey: "hubBiometricEnabled")
    }

    func authenticateWithBiometrics() async {
        guard biometricEnabled, !biometricBusy else { return }
        biometricBusy = true
        biometricError = nil
        defer { biometricBusy = false }
        let context = LAContext()
        defer { context.invalidate() }
        context.localizedFallbackTitle = "Use PIN"
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your HUB Parking account")
            guard success else { return }
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service, kSecAttrAccount as String: account,
                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationContext as String: context]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data,
                  let identifier = String(data: data, encoding: .utf8),
                  let user = User.authorizedUsers.first(where: { $0.id.uuidString == identifier }) else {
                biometricEnabled = false
                UserDefaults.standard.set(false, forKey: "hubBiometricEnabled")
                biometricError = "Sign in with your PIN and enable \(biometricName) again."
                return
            }
            currentUser = user
            UserDefaults.standard.set(user.name, forKey: "currentUser")
            showLoginError = false
            isAuthenticated = true
        } catch {
            biometricError = "Could not unlock with \(biometricName). Retry or use your PIN."
        }
    }

    func signOut() {
        shouldAutoAuthenticate = false
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "currentUser")
        showLoginError = false
        biometricError = nil
    }
}
