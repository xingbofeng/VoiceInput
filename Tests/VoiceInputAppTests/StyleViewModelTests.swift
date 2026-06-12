import XCTest
@testable import VoiceInputApp

@MainActor
final class StyleViewModelTests: XCTestCase {
    func testContainerSeedsBuiltInStylesWithOriginalAsDefault() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let viewModel = StyleViewModel(environment: environment)

        XCTAssertEqual(
            Set(viewModel.profiles.map(\.name)),
            Set(["原文", "正式", "日常", "元气", "编程", "邮件"])
        )
        XCTAssertEqual(viewModel.defaultProfile?.id, "builtin.original")
    }

    func testUpdateProfileStoresPromptAndPreservesLegacyRuntimeFields() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let viewModel = StyleViewModel(environment: environment)
        let coding = try XCTUnwrap(viewModel.profiles.first { $0.id == "builtin.coding" })

        try viewModel.updateProfile(
            id: coding.id,
            prompt: "只修正技术名词"
        )
        try viewModel.setDefaultProfile(id: coding.id)

        let saved = try XCTUnwrap(try environment.styleRepository.profile(id: coding.id))
        XCTAssertEqual(saved.prompt, "只修正技术名词")
        XCTAssertEqual(saved.llmProviderID, coding.llmProviderID)
        XCTAssertEqual(saved.model, coding.model)
        XCTAssertEqual(saved.temperature, coding.temperature)
        XCTAssertEqual(try environment.styleRepository.defaultProfile()?.id, coding.id)
    }

    func testUpdateProfileRejectsEmptyPrompt() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let viewModel = StyleViewModel(environment: environment)
        let original = try XCTUnwrap(
            try environment.styleRepository.profile(id: "builtin.coding")
        )

        XCTAssertThrowsError(
            try viewModel.updateProfile(id: original.id, prompt: " \n ")
        ) { error in
            XCTAssertEqual(error.localizedDescription, "提示词不能为空。")
        }
        XCTAssertEqual(
            try environment.styleRepository.profile(id: original.id)?.prompt,
            original.prompt
        )
    }

    func testSelectProfileImmediatelyMakesItDefaultAndSelected() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let viewModel = StyleViewModel(environment: environment)

        try viewModel.selectProfile(id: "builtin.coding")

        XCTAssertEqual(viewModel.selectedProfile?.id, "builtin.coding")
        XCTAssertEqual(viewModel.defaultProfile?.id, "builtin.coding")
        XCTAssertEqual(try environment.styleRepository.defaultProfile()?.id, "builtin.coding")
    }

    func testResetBuiltInPromptRestoresCatalogPrompt() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let viewModel = StyleViewModel(environment: environment)

        try viewModel.updateProfile(
            id: "builtin.email",
            prompt: "changed"
        )
        try viewModel.resetBuiltInPrompt(id: "builtin.email")

        let saved = try XCTUnwrap(try environment.styleRepository.profile(id: "builtin.email"))
        XCTAssertEqual(saved.prompt, BuiltInStyleCatalog.profile(id: "builtin.email")?.prompt)
        XCTAssertEqual(saved.temperature, BuiltInStyleCatalog.profile(id: "builtin.email")?.temperature)
    }

    func testAppStyleRulesPersistThroughSettingsRepository() throws {
        let environment = AppEnvironment(container: try DependencyContainer.inMemory())
        let viewModel = StyleViewModel(environment: environment)

        try viewModel.saveAppStyleRule(
            id: nil,
            bundleID: "com.example.editor",
            appName: "Editor",
            styleID: "builtin.coding"
        )

        XCTAssertEqual(viewModel.appStyleRules.count, 1)
        XCTAssertEqual(viewModel.appStyleRules.first?.bundleID, "com.example.editor")
        XCTAssertEqual(viewModel.appStyleRules.first?.styleID, "builtin.coding")

        let reloadedViewModel = StyleViewModel(environment: environment)
        XCTAssertEqual(reloadedViewModel.appStyleRules, viewModel.appStyleRules)

        reloadedViewModel.deleteAppStyleRule(id: reloadedViewModel.appStyleRules[0].id)
        XCTAssertEqual(reloadedViewModel.appStyleRules, [])
    }
}
