import AppKit

/// Settings window for LLM Refinement configuration.
/// Provides API Base URL, API Key, and Model input fields with Test and Save actions.
final class SettingsWindowController: NSWindowController {
    // MARK: - Singleton

    static let shared = SettingsWindowController()

    // MARK: - UI

    private let baseURLField = NSTextField()
    private let apiKeyField = NSSecureTextField()
    private let modelField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let testButton = NSButton()
    private let saveButton = NSButton()
    private var testSpinner: NSProgressIndicator!

    // MARK: - Init

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        setupWindow()
        setupUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupWindow() {
        guard let window = window else { return }
        window.title = "LLM Refinement 设置"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
    }

    private func setupUI() {
        guard let window = window,
              let contentView = window.contentView else { return }

        let form = NSView()
        form.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(form)

        // --- Labels ---

        let baseURLLabel = makeLabel("API Base URL:")
        let apiKeyLabel = makeLabel("API Key:")
        let modelLabel = makeLabel("Model:")

        // --- Text Fields ---

        baseURLField.placeholderString = "https://api.openai.com"
        baseURLField.translatesAutoresizingMaskIntoConstraints = false
        baseURLField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        baseURLField.controlSize = .small

        apiKeyField.placeholderString = "sk-..."
        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        apiKeyField.controlSize = .small
        // NSSecureTextField supports being completely cleared

        modelField.placeholderString = "gpt-4o-mini"
        modelField.translatesAutoresizingMaskIntoConstraints = false
        modelField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        modelField.controlSize = .small

        // --- Buttons ---

        testButton.title = "Test"
        testButton.bezelStyle = .rounded
        testButton.translatesAutoresizingMaskIntoConstraints = false
        testButton.target = self
        testButton.action = #selector(testConnection(_:))

        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.keyEquivalent = "\r"  // Enter key
        saveButton.target = self
        saveButton.action = #selector(saveSettings(_:))

        // --- Status ---

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2

        // --- Spinner ---

        testSpinner = NSProgressIndicator()
        testSpinner.style = .spinning
        testSpinner.controlSize = .small
        testSpinner.translatesAutoresizingMaskIntoConstraints = false
        testSpinner.isHidden = true

        // --- Layout ---

        form.addSubview(baseURLLabel)
        form.addSubview(baseURLField)
        form.addSubview(apiKeyLabel)
        form.addSubview(apiKeyField)
        form.addSubview(modelLabel)
        form.addSubview(modelField)
        form.addSubview(testButton)
        form.addSubview(saveButton)
        form.addSubview(statusLabel)
        form.addSubview(testSpinner)

        let labelWidth: CGFloat = 100
        NSLayoutConstraint.activate([
            // Form container
            form.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            form.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            form.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            form.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            // Base URL
            baseURLLabel.leadingAnchor.constraint(equalTo: form.leadingAnchor),
            baseURLLabel.topAnchor.constraint(equalTo: form.topAnchor),
            baseURLLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            baseURLField.leadingAnchor.constraint(equalTo: baseURLLabel.trailingAnchor, constant: 8),
            baseURLField.topAnchor.constraint(equalTo: baseURLLabel.topAnchor),
            baseURLField.trailingAnchor.constraint(equalTo: form.trailingAnchor),
            baseURLField.heightAnchor.constraint(equalToConstant: 24),

            // API Key
            apiKeyLabel.leadingAnchor.constraint(equalTo: form.leadingAnchor),
            apiKeyLabel.topAnchor.constraint(equalTo: baseURLField.bottomAnchor, constant: 12),
            apiKeyLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            apiKeyField.leadingAnchor.constraint(equalTo: apiKeyLabel.trailingAnchor, constant: 8),
            apiKeyField.topAnchor.constraint(equalTo: apiKeyLabel.topAnchor),
            apiKeyField.trailingAnchor.constraint(equalTo: form.trailingAnchor),
            apiKeyField.heightAnchor.constraint(equalToConstant: 24),

            // Model
            modelLabel.leadingAnchor.constraint(equalTo: form.leadingAnchor),
            modelLabel.topAnchor.constraint(equalTo: apiKeyField.bottomAnchor, constant: 12),
            modelLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            modelField.leadingAnchor.constraint(equalTo: modelLabel.trailingAnchor, constant: 8),
            modelField.topAnchor.constraint(equalTo: modelLabel.topAnchor),
            modelField.trailingAnchor.constraint(equalTo: form.trailingAnchor),
            modelField.heightAnchor.constraint(equalToConstant: 24),

            // Test button
            testButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12),
            testButton.topAnchor.constraint(equalTo: modelField.bottomAnchor, constant: 20),

            // Save button
            saveButton.trailingAnchor.constraint(equalTo: form.trailingAnchor),
            saveButton.topAnchor.constraint(equalTo: modelField.bottomAnchor, constant: 20),

            // Status
            statusLabel.leadingAnchor.constraint(equalTo: form.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: testButton.bottomAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: form.trailingAnchor),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: form.bottomAnchor),

            // Spinner
            testSpinner.trailingAnchor.constraint(equalTo: testButton.leadingAnchor, constant: -8),
            testSpinner.centerYAnchor.constraint(equalTo: testButton.centerYAnchor),
        ])
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        return label
    }

    // MARK: - Settings Loading / Saving

    private func loadSettings() {
        let refiner = LLMRefiner()
        baseURLField.stringValue = refiner.baseURL ?? ""
        apiKeyField.stringValue = refiner.apiKey ?? ""
        modelField.stringValue = refiner.model ?? ""
    }

    @objc private func saveSettings(_ sender: Any) {
        let refiner = LLMRefiner()

        let baseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = apiKeyField.stringValue  // Don't trim — API keys may have trailing =
        let model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        refiner.baseURL = baseURL.isEmpty ? nil : baseURL
        refiner.apiKey = apiKey.isEmpty ? nil : apiKey
        refiner.model = model.isEmpty ? nil : model

        setStatus("设置已保存。", color: .systemGreen)
    }

    @objc private func testConnection(_ sender: Any) {
        let baseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = apiKeyField.stringValue
        let model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !baseURL.isEmpty, !apiKey.isEmpty, !model.isEmpty else {
            setStatus("请填写所有字段后再测试。", color: .systemOrange)
            return
        }

        testButton.isEnabled = false
        testSpinner.isHidden = false
        testSpinner.startAnimation(nil)
        setStatus("正在测试连接...", color: .secondaryLabelColor)

        Task {
            let refiner = LLMRefiner()
            let result = await refiner.testConnection(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model
            )

            await MainActor.run {
                self.testButton.isEnabled = true
                self.testSpinner.isHidden = true
                self.testSpinner.stopAnimation(nil)

                switch result {
                case .success(let message):
                    self.setStatus(message, color: .systemGreen)
                case .failure(let error):
                    self.setStatus("连接失败：\(error.localizedDescription)", color: .systemRed)
                }
            }
        }
    }

    private func setStatus(_ text: String, color: NSColor) {
        statusLabel.stringValue = text
        statusLabel.textColor = color
    }

    // MARK: - Show

    func show() {
        loadSettings()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
