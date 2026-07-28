import CoreFoundation
import Foundation

struct FinderActionDescriptor: Identifiable, Hashable {
    var id: FinderMenuAction { action }
    let action: FinderMenuAction
    let symbol: String
    let title: String
    let detail: String
}

struct ExtensionControlAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

final class ExtensionManager: ObservableObject {
    @Published private(set) var enabledByID: [FinderMenuAction: Bool] = [:]
    @Published private(set) var busyIDs: Set<FinderMenuAction> = []
    @Published private(set) var isRefreshing = false
    @Published var alert: ExtensionControlAlert?

    func enabledState(for action: FinderActionDescriptor) -> Bool? {
        enabledByID[action.id]
    }

    func isBusy(_ action: FinderActionDescriptor) -> Bool {
        busyIDs.contains(action.id)
    }

    func refresh(_ actions: [FinderActionDescriptor]) {
        guard !isRefreshing, busyIDs.isEmpty else { return }
        isRefreshing = true

        DispatchQueue.global(qos: .userInitiated).async {
            var states: [FinderMenuAction: Bool] = [:]
            var firstError: Error?

            do {
                try SystemExtensionController.prepareFinderMenu()
                states = FinderMenuSettings.enabledStates()
            } catch {
                firstError = error
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.enabledByID = states
                self.isRefreshing = false
                if let firstError {
                    self.alert = ExtensionControlAlert(
                        title: "未能读取功能状态",
                        message: firstError.localizedDescription
                    )
                }
            }
        }
    }

    func setEnabled(_ enabled: Bool, for action: FinderActionDescriptor) {
        guard !isRefreshing, !busyIDs.contains(action.id) else { return }

        let actionID = action.id
        let previousValue = enabledByID[actionID] ?? !enabled
        enabledByID[actionID] = enabled
        busyIDs.insert(actionID)

        DispatchQueue.global(qos: .userInitiated).async {
            var actualValue = previousValue
            var operationError: Error?

            do {
                try FinderMenuSettings.setEnabled(enabled, for: action.action)
                try SystemExtensionController.enableFinderSync()
                actualValue = FinderMenuSettings.isEnabled(action.action)
                guard actualValue == enabled else {
                    throw ExtensionControlError.stateDidNotChange(action.title)
                }
            } catch {
                operationError = error
                actualValue = FinderMenuSettings.isEnabled(action.action)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.enabledByID[actionID] = actualValue
                self.busyIDs.remove(actionID)
                if let operationError {
                    self.alert = ExtensionControlAlert(
                        title: "未能更新“\(action.title)”",
                        message: operationError.localizedDescription
                    )
                }
            }
        }
    }
}

private enum SystemExtensionController {
    private static let finderSyncIdentifier = "com.qingmeng.SuperRightClick.CurrentFolderFinderSync"
    private static let preferencesApplicationID = "pbs" as CFString
    private static let finderActiveKey = "FinderActive" as CFString
    private static let legacyQuickActions = [
        (
            identifier: "com.qingmeng.SuperRightClick.CopyPathAction",
            preferenceKey: "APPEXTENSION-com.qingmeng.SuperRightClick.CopyPathAction",
            action: FinderMenuAction.copyPath
        ),
        (
            identifier: "com.qingmeng.SuperRightClick.HideSelectedAction",
            preferenceKey: "APPEXTENSION-com.qingmeng.SuperRightClick.HideSelectedAction",
            action: FinderMenuAction.hideSelected
        )
    ]

    static func prepareFinderMenu() throws {
        let isFirstMigration = !FinderMenuSettings.hasStoredSettings()
        if isFirstMigration {
            var states = Dictionary(
                uniqueKeysWithValues: FinderMenuAction.allCases.map { ($0, true) }
            )
            for legacy in legacyQuickActions {
                states[legacy.action] = legacyQuickActionEnabled(legacy.preferenceKey) ?? true
            }
            states[.unhideFolderContents] = (try? isPluginEnabled(finderSyncIdentifier)) ?? true
            try FinderMenuSettings.saveInitialStates(states)
        }

        let legacyMenuChanged = try disableLegacyQuickActions()
        try enableFinderSync()
        if legacyMenuChanged {
            try reloadFinder()
        }
    }

    static func enableFinderSync() throws {
        try setPluginEnabled(true, bundleIdentifier: finderSyncIdentifier)
    }

    static func reloadFinder() throws {
        _ = try? run(executable: "/usr/bin/killall", arguments: ["pbs"])
        _ = try run(executable: "/usr/bin/killall", arguments: ["Finder"])
    }

    private static func legacyQuickActionEnabled(_ preferenceKey: String) -> Bool? {
        CFPreferencesAppSynchronize(preferencesApplicationID)
        guard
            let dictionary = CFPreferencesCopyAppValue(
                finderActiveKey,
                preferencesApplicationID
            ) as? [String: Any],
            let value = dictionary[preferenceKey]
        else {
            return nil
        }
        if let boolean = value as? Bool {
            return boolean
        }
        return (value as? NSNumber)?.boolValue
    }

    private static func disableLegacyQuickActions() throws -> Bool {
        CFPreferencesAppSynchronize(preferencesApplicationID)
        var dictionary = CFPreferencesCopyAppValue(
            finderActiveKey,
            preferencesApplicationID
        ) as? [String: Any] ?? [:]
        var changed = false

        for legacy in legacyQuickActions {
            if legacyQuickActionEnabled(legacy.preferenceKey) == true {
                dictionary[legacy.preferenceKey] = false
                changed = true
            }
            try? setPluginEnabled(false, bundleIdentifier: legacy.identifier)
        }

        guard changed else { return false }

        CFPreferencesSetAppValue(
            finderActiveKey,
            dictionary as CFDictionary,
            preferencesApplicationID
        )
        guard CFPreferencesAppSynchronize(preferencesApplicationID) else {
            throw ExtensionControlError.preferenceWriteFailed
        }
        return true
    }

    private static func isPluginEnabled(_ bundleIdentifier: String) throws -> Bool {
        let output = try run(
            executable: "/usr/bin/pluginkit",
            arguments: ["-m", "-i", bundleIdentifier]
        )
        guard let matchingLine = output
            .split(separator: "\n")
            .first(where: { $0.contains(bundleIdentifier) })
        else {
            throw ExtensionControlError.extensionNotFound("Finder 右键")
        }
        return matchingLine.trimmingCharacters(in: .whitespaces).hasPrefix("+")
    }

    private static func setPluginEnabled(_ enabled: Bool, bundleIdentifier: String) throws {
        _ = try run(
            executable: "/usr/bin/pluginkit",
            arguments: ["-e", enabled ? "use" : "ignore", "-i", bundleIdentifier]
        )
    }

    @discardableResult
    private static func run(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw ExtensionControlError.commandCouldNotStart(error.localizedDescription)
        }

        process.waitUntilExit()
        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        let errorOutput = String(decoding: errorData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw ExtensionControlError.commandFailed(
                errorOutput.isEmpty ? "系统命令返回错误 \(process.terminationStatus)。" : errorOutput
            )
        }
        return output
    }
}

private enum ExtensionControlError: LocalizedError {
    case commandCouldNotStart(String)
    case commandFailed(String)
    case extensionNotFound(String)
    case preferenceWriteFailed
    case stateDidNotChange(String)

    var errorDescription: String? {
        switch self {
        case .commandCouldNotStart(let message):
            return "无法启动系统扩展管理工具：\(message)"
        case .commandFailed(let message):
            return "系统未接受这次修改：\(message)"
        case .extensionNotFound(let title):
            return "系统尚未注册“\(title)”扩展。请重新打开右键派后再试。"
        case .preferenceWriteFailed:
            return "无法保存 Finder 快速操作设置。"
        case .stateDidNotChange(let title):
            return "“\(title)”的系统状态没有发生变化。"
        }
    }
}
