import AppKit
import Speech
import AVFoundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - UI

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var languageMenuItems: [NSMenuItem] = []
    private var llmToggleItem: NSMenuItem!
    private var llmSettingsItem: NSMenuItem!
    private var refiningMenuItem: NSMenuItem!

    // MARK: - Subsystems

    private let keyMonitor = KeyMonitor()
    private let audioRecorder = AudioRecorder()
    private let speechRecognizer = SpeechRecognizer()
    private let textInjector = TextInjector()
    private let llmRefiner = LLMRefiner()
    private let overlayController = OverlayWindowController()

    // MARK: - State

    private enum AppState {
        case idle
        case recording
        case refining
        case injecting
    }

    private var state: AppState = .idle
    private var transcriptionSession = TranscriptionSession()
    private var finishTimeoutTask: Task<Void, Never>?
    private var permissionsResolved = false
    private var hasRecordingPermissions = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()

        audioRecorder.delegate = self

        // Default language
        let lang = LanguageManager.shared.currentLanguage
        speechRecognizer.configure(locale: lang.locale)

        // Start key monitor
        setupKeyMonitor()

        Task {
            await resolveRecordingPermissions()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyMonitor.stop()
        audioRecorder.stop()
        speechRecognizer.cancel()
        finishTimeoutTask?.cancel()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // Use SF Symbol for microphone
            let image = NSImage(
                systemSymbolName: "mic.fill",
                accessibilityDescription: "VoiceInput"
            )
            button.image = image
            button.imagePosition = .imageOnly
            // Subtle tint
            button.contentTintColor = .controlAccentColor
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        menu.autoenablesItems = false

        // Language submenu
        let languageMenu = NSMenu()
        languageMenu.autoenablesItems = false
        for lang in RecognitionLanguage.allCases {
            let item = NSMenuItem(
                title: lang.displayName,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.representedObject = lang
            item.target = self
            item.state = (lang == LanguageManager.shared.currentLanguage) ? .on : .off
            languageMenu.addItem(item)
            languageMenuItems.append(item)
        }

        let languageParentItem = NSMenuItem()
        languageParentItem.title = "语言 / Language"
        languageParentItem.submenu = languageMenu
        menu.addItem(languageParentItem)

        menu.addItem(.separator())

        // LLM Refinement submenu
        let llmMenu = NSMenu()
        llmMenu.autoenablesItems = false

        llmToggleItem = NSMenuItem(
            title: "LLM 纠错已关闭",
            action: #selector(toggleLLM(_:)),
            keyEquivalent: ""
        )
        llmToggleItem.target = self
        llmMenu.addItem(llmToggleItem)
        updateLLMToggleTitle()

        llmSettingsItem = NSMenuItem(
            title: "LLM 设置...",
            action: #selector(openLLMSettings(_:)),
            keyEquivalent: ""
        )
        llmSettingsItem.target = self
        llmMenu.addItem(llmSettingsItem)

        let llmParentItem = NSMenuItem()
        llmParentItem.title = "LLM Refinement"
        llmParentItem.submenu = llmMenu
        menu.addItem(llmParentItem)

        // Refining status (shown during active LLM refinement)
        refiningMenuItem = NSMenuItem(
            title: "Refining...",
            action: nil,
            keyEquivalent: ""
        )
        refiningMenuItem.isHidden = true
        menu.addItem(refiningMenuItem)

        menu.addItem(.separator())

        // Quit
        let checkPermissionsItem = NSMenuItem(
            title: "检查权限...",
            action: #selector(checkPermissions(_:)),
            keyEquivalent: ""
        )
        checkPermissionsItem.target = self
        menu.addItem(checkPermissionsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 VoiceInput",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateLLMToggleTitle() {
        let enabled = llmRefiner.isEnabled
        llmToggleItem.title = enabled ? "LLM 纠错已开启 ✓" : "LLM 纠错已关闭"
    }

    private func updateLanguageMenuState() {
        let current = LanguageManager.shared.currentLanguage
        for item in languageMenuItems {
            item.state = (item.representedObject as? RecognitionLanguage) == current ? .on : .off
        }
    }

    // MARK: - Menu Actions

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? RecognitionLanguage else { return }
        LanguageManager.shared.setLanguage(lang)
        updateLanguageMenuState()

        // Reconfigure recognizer with new locale
        speechRecognizer.configure(locale: lang.locale)
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        llmRefiner.isEnabled.toggle()
        updateLLMToggleTitle()
    }

    @objc private func openLLMSettings(_ sender: NSMenuItem) {
        SettingsWindowController.shared.show()
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Key Monitor

    private func setupKeyMonitor() {
        keyMonitor.onHotKeyPress = { [weak self] in
            self?.handleHotKeyPress()
        }
        keyMonitor.onHotKeyRelease = { [weak self] in
            self?.handleHotKeyRelease()
        }

        guard keyMonitor.start() else {
            // Accessibility permission not granted
            DispatchQueue.main.async {
                self.showAccessibilityAlert()
            }
            return
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
            VoiceInput 需要"辅助功能"权限来监听右 Command 键的全局输入。

            请在 系统设置 → 隐私与安全性 → 辅助功能 中，
            添加并启用 VoiceInput。
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }

    // MARK: - Hot Key Handling

    private func handleHotKeyPress() {
        guard case .idle = state else { return }
        guard permissionsResolved, hasRecordingPermissions else {
            if permissionsResolved {
                showRecordingPermissionsAlert()
            }
            return
        }

        transcriptionSession = TranscriptionSession()
        finishTimeoutTask?.cancel()

        do {
            speechRecognizer.configure(locale: LanguageManager.shared.currentLanguage.locale)

            speechRecognizer.onTranscription = { [weak self] text, isFinal in
                guard let self, case .recording = self.state else { return }
                self.overlayController.updateTranscription(text, isRefining: false)
                if let completedText = self.transcriptionSession.update(
                    text: text,
                    isFinal: isFinal
                ) {
                    self.finishRecording(with: completedText)
                }
            }
            speechRecognizer.onError = { [weak self] error in
                guard let self, case .recording = self.state else { return }
                if let partialText = self.transcriptionSession.timeout() {
                    self.finishRecording(with: partialText)
                } else {
                    self.handleRecognitionError(error)
                }
            }

            try speechRecognizer.start()
            try audioRecorder.start()

            state = .recording

            overlayController.show()
            overlayController.updateTranscription("", isRefining: false)
            refiningMenuItem.isHidden = true
        } catch {
            if let recognizerError = error as? SpeechRecognizer.Error {
                handleRecognitionError(recognizerError)
            } else {
                handleRecordingError(error)
            }
        }
    }

    private func handleHotKeyRelease() {
        guard case .recording = state else {
            return
        }

        audioRecorder.stop()
        speechRecognizer.endAudio()

        if let completedText = transcriptionSession.release() {
            finishRecording(with: completedText)
            return
        }

        finishTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled,
                  let self,
                  case .recording = self.state,
                  let partialText = self.transcriptionSession.timeout() else {
                return
            }
            self.finishRecording(with: partialText)
        }
    }

    private func finishRecording(with recognizedText: String) {
        finishTimeoutTask?.cancel()
        finishTimeoutTask = nil
        audioRecorder.stop()
        speechRecognizer.stop()

        let finalText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else {
            overlayController.dismiss()
            state = .idle
            return
        }

        if llmRefiner.isEnabled && llmRefiner.isConfigured {
            // Show refining state
            state = .refining
            overlayController.updateTranscription(finalText, isRefining: true)
            refiningMenuItem.isHidden = false

            Task {
                await refineText(finalText)
            }
        } else {
            overlayController.dismiss()
            state = .injecting
            Task {
                await textInjector.inject(finalText)
                self.state = .idle
            }
        }
    }

    // MARK: - LLM Refinement

    private func refineText(_ text: String) async {
        let textToInject: String
        do {
            textToInject = try await llmRefiner.refine(text)
        } catch {
            textToInject = text
        }

        overlayController.dismiss()
        refiningMenuItem.isHidden = true
        state = .injecting
        await textInjector.inject(textToInject)
        state = .idle
    }

    // MARK: - Error Handling

    private func resolveRecordingPermissions() async {
        let micStatus = AudioRecorder.checkPermission()
        let speechStatus = SpeechRecognizer.checkPermission()

        var microphoneGranted = (micStatus == .granted)
        var speechAuthorized = (speechStatus == .granted)

        // Only request if not yet determined — don't re-prompt for already denied
        if micStatus == .notDetermined {
            microphoneGranted = await AudioRecorder.requestPermission()
        }
        if speechStatus == .notDetermined {
            let status = await SpeechRecognizer.requestPermission()
            speechAuthorized = (status == .authorized)
        }

        permissionsResolved = true
        hasRecordingPermissions = microphoneGranted && speechAuthorized
    }

    private func checkAllPermissions() {
        let mic = AudioRecorder.checkPermission()
        let speech = SpeechRecognizer.checkPermission()
        let accessibility = AXIsProcessTrusted()

        func statusText(_ granted: Bool) -> String { granted ? "✅ 已授予" : "❌ 未授予" }

        let alert = NSAlert()
        alert.messageText = "权限状态"
        alert.informativeText = """
        辅助功能：\(statusText(accessibility))
        麦克风：\(statusText(mic == .granted))
        语音识别：\(statusText(speech == .granted))
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "确定")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
            )
        }
    }

    @objc private func checkPermissions(_ sender: NSMenuItem) {
        checkAllPermissions()
    }

    private func showRecordingPermissionsAlert() {
        let alert = NSAlert()
        alert.messageText = "需要录音与语音识别权限"
        alert.informativeText = """
            VoiceInput 需要麦克风和语音识别权限才能工作。

            请在 系统设置 → 隐私与安全性 中启用“麦克风”和“语音识别”权限。
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity")!
            )
        }
    }

    private func handleRecognitionError(_ error: Error) {
        finishTimeoutTask?.cancel()
        finishTimeoutTask = nil
        audioRecorder.stop()
        speechRecognizer.cancel()
        overlayController.dismiss()
        state = .idle

        let alert = NSAlert()
        alert.messageText = "语音识别错误"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    private func handleRecordingError(_ error: Error) {
        finishTimeoutTask?.cancel()
        finishTimeoutTask = nil
        audioRecorder.stop()
        speechRecognizer.cancel()
        overlayController.dismiss()
        state = .idle

        let alert = NSAlert()
        alert.messageText = "录音错误"
        alert.informativeText = """
            无法启动录音：\(error.localizedDescription)

            请在 系统设置 → 隐私与安全性 → 麦克风 中启用 VoiceInput。
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

// MARK: - AudioRecorder Delegate

extension AppDelegate: AudioRecorder.Delegate {
    func audioRecorder(_ recorder: AudioRecorder, didReceiveBuffer buffer: AVAudioPCMBuffer) {
        speechRecognizer.appendAudioBuffer(buffer)
    }

    func audioRecorder(_ recorder: AudioRecorder, didUpdateRMS rms: Float) {
        overlayController.updateRMS(rms)
    }
}
