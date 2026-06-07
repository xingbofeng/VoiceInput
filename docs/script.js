const copy = {
  zh: {
    eyebrow: "原生 macOS 语音输入",
    headlineA: "说出来。",
    headlineB: "它替你写。",
    heroCopy: "按住右 Command，自然说话，松手即输入。VoiceInput 让中文、英文与技术术语顺畅落在任何光标之后。",
    download: "下载 macOS App",
    downloadMeta: "macOS 14+ · Apple Silicon + Intel",
    releaseNote: "v1.0.0 · 免费开源",
    transcript: "让声音越过键盘，直接抵达光标。",
    holdHint: "按住说话",
    flowTitle: "没有录音按钮。<br>没有上下文切换。",
    flowCopy: "VoiceInput 常驻菜单栏，却从不占据你的注意力。它只在你按住右 Command 时出现，松手后把文字送回原来的工作现场。",
    featureNativeTitle: "原生速度",
    featureNativeCopy: "Apple Speech 流式转录，真实 RMS 驱动波形。声音有多大，界面就有多鲜活。",
    featureLanguageTitle: "中文优先，多语自由",
    featureLanguageCopy: "简体中文开箱即用，并可随时切换英语、繁中、日语与韩语。",
    featureRefineTitle: "只纠错，不替你说话",
    featureRefineCopy: "可选的 OpenAI-compatible LLM 只修复明显误识别。正确的内容、语气和措辞保持原样。",
    privacyTitle: "你的输入现场，<br>结束后恢复原样。",
    privacyCopy: "输入法临时切换后自动恢复，剪贴板所有 item 与类型完整还原。无分析、无遥测；LLM 只有在你主动开启时才接收识别后的文本。",
    ctaTitle: "让下一句话，<br>直接成为文字。",
    footer: "Swift & AppKit · 开源"
  },
  en: {
    eyebrow: "Native voice input for macOS",
    headlineA: "Speak.",
    headlineB: "It types.",
    heroCopy: "Hold Right Command, speak naturally, and release. VoiceInput puts Chinese, English, and technical terms exactly where your cursor is.",
    download: "Download for macOS",
    downloadMeta: "macOS 14+ · Apple Silicon + Intel",
    releaseNote: "v1.0.0 · Free & open source",
    transcript: "Let your voice skip the keyboard and meet the cursor.",
    holdHint: "Hold to speak",
    flowTitle: "No record button.<br>No context switching.",
    flowCopy: "VoiceInput lives in the menu bar without asking for your attention. It appears while you hold Right Command, then returns the words to the exact place you were working.",
    featureNativeTitle: "Native speed",
    featureNativeCopy: "Streaming Apple Speech transcription with a waveform driven by real microphone RMS. The interface responds to your actual voice.",
    featureLanguageTitle: "Chinese first. Multilingual by choice.",
    featureLanguageCopy: "Simplified Chinese works out of the box, with English, Traditional Chinese, Japanese, and Korean one menu away.",
    featureRefineTitle: "Correction, never rewriting",
    featureRefineCopy: "Optional OpenAI-compatible refinement fixes only obvious recognition errors. Correct wording, voice, and intent remain untouched.",
    privacyTitle: "Your workspace returns<br>exactly as it was.",
    privacyCopy: "Input sources switch back automatically, and every clipboard item and type is restored. No analytics, no telemetry; the LLM only receives recognized text when you explicitly enable it.",
    ctaTitle: "Make your next sentence<br>appear as text.",
    footer: "Swift & AppKit · Open source"
  }
};

const languageButton = document.querySelector(".language-switch");
const languageLabel = document.querySelector("[data-lang-label]");
const initialLanguage = localStorage.getItem("voiceinput-language")
  ?? (navigator.language.toLowerCase().startsWith("zh") ? "zh" : "en");

function setLanguage(language) {
  const selected = copy[language];
  document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const value = selected[element.dataset.i18n];
    if (value) element.innerHTML = value;
  });
  languageLabel.textContent = language === "zh" ? "EN" : "中";
  languageButton.dataset.language = language;
  localStorage.setItem("voiceinput-language", language);
}

languageButton.addEventListener("click", () => {
  setLanguage(languageButton.dataset.language === "zh" ? "en" : "zh");
});

setLanguage(initialLanguage);
