import Foundation

protocol LLMCompletionSession: AnyObject, Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: LLMCompletionSession {}

protocol ActiveLLMProviderIdentifying {
    var activeProviderID: String? { get }
}

final class RepositoryBackedLLMRefiner: TextRefining, PromptAwareTextRefining, ActiveLLMProviderIdentifying, @unchecked Sendable {
    static let enabledDefaultsKey = "LLMRefiner_Enabled"

    private let providerRepository: any LLMProviderRepository
    private let credentialStore: CredentialStore
    private let defaults: UserDefaults
    private let session: any LLMCompletionSession
    private(set) var activeProviderID: String?

    init(
        providerRepository: any LLMProviderRepository,
        credentialStore: CredentialStore,
        defaults: UserDefaults = .standard,
        session: any LLMCompletionSession = URLSession.shared
    ) {
        self.providerRepository = providerRepository
        self.credentialStore = credentialStore
        self.defaults = defaults
        self.session = session
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledDefaultsKey) }
        set { defaults.set(newValue, forKey: Self.enabledDefaultsKey) }
    }

    var isConfigured: Bool {
        guard let provider = try? configuredProvider(),
              let key = try? credentialStore.readCredential(account: provider.apiKeyRef) else {
            return false
        }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func refine(_ text: String) async throws -> String {
        try await refine(
            TextRefinementRequest(
                text: text,
                systemPrompt: PromptBuilder.conservativeSystemPrompt,
                model: nil,
                temperature: nil
            )
        )
    }

    func refine(_ request: TextRefinementRequest) async throws -> String {
        let provider = try configuredProvider()
        guard let apiKey = try credentialStore.readCredential(account: provider.apiKeyRef),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMRefiner.Error.notConfigured
        }

        let url = try OpenAICompatibleClient.chatCompletionsURL(baseURL: provider.baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = provider.timeoutSeconds
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": provider.defaultModel,
            "messages": [
                ["role": "system", "content": request.systemPrompt],
                ["role": "user", "content": request.text],
            ],
            "temperature": provider.temperature,
            "max_tokens": max(100, request.text.count + 50),
            "stream": false,
        ])

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMRefiner.Error.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw LLMRefiner.Error.httpError(code: httpResponse.statusCode)
        }
        activeProviderID = provider.id
        let refined = try LLMRefiner.parseChatCompletion(data)
        return refined.isEmpty ? request.text : refined
    }

    private func configuredProvider() throws -> LLMProviderRecord {
        guard let provider = try providerRepository.list().first(where: { $0.enabled && $0.isDefault }),
              !provider.baseURL.isEmpty,
              !provider.defaultModel.isEmpty else {
            throw LLMRefiner.Error.notConfigured
        }
        return provider
    }
}
