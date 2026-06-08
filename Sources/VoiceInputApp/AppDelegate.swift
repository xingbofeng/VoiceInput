import AppKit
import Speech
import AVFoundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // MARK: - UI

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var languageMenuItems: [NSMenuItem] = []
    private var asrEngineMenuItems: [NSMenuItem] = []
    private var llmToggleItem: NSMenuItem!
    private var refiningMenuItem: NSMenuItem!
    private var settingsItem: NSMenuItem!

    // MARK: - Subsystems

    private let keyMonitor = KeyMonitor()
    private let audioRecorder = AudioRecorder()
    private let asrManager = ASRManager()
    private let textInjector = TextInjector()
    private let llmRefiner = LLMRefiner()
    private let overlayController = OverlayWindowController()

    private var currentEngine: ASREngine?

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
    private var escEventMonitor: Any?

    /// Scheduled task that starts recording after longPressThreshold.
    /// Cancelled by onShortPress so the toggle logic takes over instead.
    private var delayedPressTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()

        audioRecorder.delegate = self

        // Start key monitor
        setupKeyMonitor()

        Task {
            await resolveRecordingPermissions()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyMonitor.stop()
        delayedPressTask?.cancel()
        audioRecorder.stop()
        currentEngine?.cancel()
        finishTimeoutTask?.cancel()
        stopEscMonitor()
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
        menu.delegate = self

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

        // ASR Engine submenu
        setupASREngineMenu()

        menu.addItem(.separator())

        // Settings
        settingsItem = NSMenuItem(
            title: "设置...",
            action: #selector(openSettings(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        llmToggleItem = NSMenuItem(
            title: "LLM 纠错已关闭",
            action: #selector(toggleLLM(_:)),
            keyEquivalent: ""
        )
        llmToggleItem.target = self
        menu.addItem(llmToggleItem)
        updateLLMToggleTitle()

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

    func menuWillOpen(_ menu: NSMenu) {
        updateASREngineMenuState()
        updateLLMToggleTitle()
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
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        llmRefiner.isEnabled.toggle()
        updateLLMToggleTitle()
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        SettingsWindowController.shared.show(tab: .asr)
    }

    // MARK: - ASR Engine Menu

    private func setupASREngineMenu() {
        let asrMenu = NSMenu()
        asrMenu.autoenablesItems = false

        for engineType in ASREngineType.allCases {
            let item = NSMenuItem(
                title: engineType.rawValue,
                action: #selector(selectASREngine(_:)),
                keyEquivalent: ""
            )
            item.representedObject = engineType
            item.target = self
            item.isEnabled = asrManager.canSelectEngine(engineType)
            item.state = (engineType == asrManager.effectiveSelectedEngineType) ? .on : .off
            asrMenu.addItem(item)
            asrEngineMenuItems.append(item)
        }

        let asrParentItem = NSMenuItem()
        asrParentItem.title = "语音识别引擎"
        asrParentItem.submenu = asrMenu
        menu.addItem(asrParentItem)
    }

    @objc private func selectASREngine(_ sender: NSMenuItem) {
        guard let engineType = sender.representedObject as? ASREngineType else { return }
        asrManager.selectEngine(engineType)
        updateASREngineMenuState()
    }

    private func updateASREngineMenuState() {
        let effective = asrManager.effectiveSelectedEngineType
        for item in asrEngineMenuItems {
            guard let engineType = item.representedObject as? ASREngineType else { continue }
            item.isEnabled = asrManager.canSelectEngine(engineType)
            item.state = engineType == effective ? .on : .off
        }
    }

    // MARK: - Quit

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Key Monitor

    private func setupKeyMonitor() {
        keyMonitor.onHotKeyPress = { [weak self] in
            guard let self, case .idle = self.state else { return }

            // Delay recording start by longPressThreshold. If the user
            // releases before the threshold (short press), onShortPress
            // cancels this task and toggles recording instead.
            let threshold = ShortcutManager.shared.longPressThreshold
            let task = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(threshold * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                self.delayedPressTask = nil
                self.handleHotKeyPress()
            }
            delayedPressTask = task
        }
        keyMonitor.onHotKeyRelease = { [weak self] in
            self?.delayedPressTask?.cancel()
            self?.delayedPressTask = nil
            self?.handleHotKeyRelease()
        }
        keyMonitor.onShortPress = { [weak self] in
            guard let self else { return }

            // Cancel any pending long-press start — this is a short press.
            self.delayedPressTask?.cancel()
            self.delayedPressTask = nil

            // Toggle recording on short press.
            switch self.state {
            case .recording:
                self.handleHotKeyRelease()
            case .idle:
                self.handleHotKeyPress()
            case .refining, .injecting:
                break
            }
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
        refreshRecordingPermissionState()
        guard permissionsResolved, hasRecordingPermissions else {
            if permissionsResolved {
                showRecordingPermissionsAlert()
            }
            return
        }

        transcriptionSession = TranscriptionSession()
        finishTimeoutTask?.cancel()

        let engineType = asrManager.effectiveSelectedEngineType
        let engine = asrManager.makeEngine(type: engineType)
        currentEngine = engine

        engine.configure(locale: LanguageManager.shared.currentLanguage.locale)
        engine.onTranscription = { [weak self] text, isFinal in
            guard let self, case .recording = self.state else { return }
            self.overlayController.updateTranscription(text, isRefining: false)
            if let completedText = self.transcriptionSession.update(
                text: text,
                isFinal: isFinal
            ) {
                self.finishRecording(with: completedText)
            }
        }
        engine.onError = { [weak self] error in
            guard let self, case .recording = self.state else { return }
            if let partialText = self.transcriptionSession.timeout() {
                self.finishRecording(with: partialText)
            } else {
                self.handleRecognitionError(error)
            }
        }

        do {
            try engine.start()
        } catch {
            handleRecognitionError(error)
            return
        }

        do {
            try audioRecorder.start()
        } catch {
            engine.cancel()
            if error is AudioRecorder.AudioRecorderError {
                showRecordingPermissionsAlert()
            } else {
                handleRecognitionError(error)
            }
            return
        }

        state = .recording

        // Listen for ESC to cancel the recording.
        escEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {  // ESC
                DispatchQueue.main.async {
                    self?.cancelRecording()
                }
            }
        }

        overlayController.show()
        overlayController.updateTranscription("", isRefining: false)
        refiningMenuItem.isHidden = true
    }

    private func handleHotKeyRelease() {
        guard case .recording = state else {
            return
        }

        audioRecorder.stop()
        currentEngine?.endAudio()

        // Qwen3 processes audio in batch after recording ends — show a
        // processing indicator so the user knows inference is in progress.
        if currentEngine is Qwen3ASREngine {
            overlayController.updateTranscription("正在识别...", isRefining: true)
        }

        if let completedText = transcriptionSession.release() {
            finishRecording(with: completedText)
            return
        }

        finishTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled,
                  let self,
                  case .recording = self.state else {
                return
            }
            self.handleRecognitionError(ASREngineError.modelNotLoaded)
        }
    }

    private func finishRecording(with recognizedText: String) {
        stopEscMonitor()
        finishTimeoutTask?.cancel()
        finishTimeoutTask = nil
        audioRecorder.stop()
        currentEngine?.stop()

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
        // Qwen3-ASR only needs microphone, not Apple Speech
        let engineType = asrManager.effectiveSelectedEngineType

        if engineType == .qwen3 {
            let micStatus = AudioRecorder.checkPermission()
            if micStatus == .notDetermined {
                _ = await AudioRecorder.requestPermission()
            }
            let microphoneGranted = AudioRecorder.checkPermission() == .granted
        permissionsResolved = true
        hasRecordingPermissions = RecordingPermissionPolicy.hasRequiredPermissions(
            engineType: .qwen3,
            microphonePermission: microphoneGranted ? .granted : .denied,
            speechPermission: .denied
        )
        return
    }

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
        hasRecordingPermissions = RecordingPermissionPolicy.hasRequiredPermissions(
            engineType: .apple,
            microphonePermission: microphoneGranted ? .granted : .denied,
            speechPermission: speechAuthorized ? .granted : .denied
        )
    }

    private func refreshRecordingPermissionState() {
        let engineType = asrManager.effectiveSelectedEngineType

        permissionsResolved = true
        hasRecordingPermissions = RecordingPermissionPolicy.hasRequiredPermissions(
            engineType: engineType,
            microphonePermission: AudioRecorder.checkPermission(),
            speechPermission: SpeechRecognizer.checkPermission()
        )
    }

    private func checkAllPermissions() {
        let mic = AudioRecorder.checkPermission()
        let speech = SpeechRecognizer.checkPermission()
        let accessibility = AXIsProcessTrusted()
        let engineType = asrManager.effectiveSelectedEngineType

        let alert = NSAlert()
        alert.messageText = "权限状态"
        alert.informativeText = """
        辅助功能：\(PermissionSummary.statusText(accessibility))
        麦克风：\(PermissionSummary.statusText(mic == .granted))
        语音识别：\(PermissionSummary.speechRecognitionStatus(engineType: engineType, speechPermission: speech))
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
        let message = PermissionSummary.recordingPermissionAlertText(
            engineType: asrManager.effectiveSelectedEngineType
        )
        let alert = NSAlert()
        alert.messageText = message.title
        alert.informativeText = message.body
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
        stopEscMonitor()
        finishTimeoutTask?.cancel()
        finishTimeoutTask = nil
        audioRecorder.stop()
        currentEngine?.cancel()
        overlayController.dismiss()
        state = .idle

        let alert = NSAlert()
        alert.messageText = "语音识别错误"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    /// Cancel the current recording without injecting any text.
    private func cancelRecording() {
        guard case .recording = state else { return }
        stopEscMonitor()
        finishTimeoutTask?.cancel()
        finishTimeoutTask = nil
        audioRecorder.stop()
        currentEngine?.cancel()
        overlayController.dismiss()
        state = .idle
    }

    private func stopEscMonitor() {
        if let monitor = escEventMonitor {
            NSEvent.removeMonitor(monitor)
            escEventMonitor = nil
        }
    }
}

// MARK: - AudioRecorder Delegate

extension AppDelegate: AudioRecorder.Delegate {
    func audioRecorder(_ recorder: AudioRecorder, didReceiveBuffer buffer: AVAudioPCMBuffer) {
        currentEngine?.appendAudioBuffer(buffer)
    }

    func audioRecorder(_ recorder: AudioRecorder, didUpdateRMS rms: Float) {
        overlayController.updateRMS(rms)
    }
}
