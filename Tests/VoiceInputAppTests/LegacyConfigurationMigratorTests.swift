import XCTest
@testable import VoiceInputApp

final class LegacyConfigurationMigratorTests: XCTestCase {
    func testMigratesLegacyLLMSettingsAndBuiltInPrompts() throws {
        let suiteName = "LegacyConfigurationMigratorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("https://api.example.com/v1", forKey: "LLMRefiner_BaseURL")
        defaults.set("legacy-model", forKey: "LLMRefiner_Model")
        let credentials = MigratorCredentialStore()
        try credentials.saveCredential("secret", account: "llm-api-key")
        let container = try DependencyContainer.inMemory(
            credentialStore: credentials,
            defaults: defaults
        )

        let provider = try XCTUnwrap(container.llmProviderRepository.list().first)
        XCTAssertTrue(provider.isDefault)
        XCTAssertEqual(provider.defaultModel, "legacy-model")
        XCTAssertEqual(provider.apiKeyRef, "llm-api-key")
        XCTAssertEqual(
            try container.styleRepository.profile(id: "builtin.coding")?.prompt,
            BuiltInStyleCatalog.profile(id: "builtin.coding")?.prompt
        )
    }
}

private final class MigratorCredentialStore: CredentialStore {
    private var values: [String: String] = [:]
    func readCredential(account: String) throws -> String? { values[account] }
    func saveCredential(_ value: String, account: String) throws { values[account] = value }
    func deleteCredential(account: String) throws { values.removeValue(forKey: account) }
}
