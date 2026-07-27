import CoreFoundation
import Foundation

struct FinderActionDescriptor: Identifiable, Hashable {
    enum Control: Hashable {
        case quickAction(preferenceKey: String)
        case finderSync
    }

    let id: String
    let symbol: String
    let title: String
    let detail: String
    let control: Control
}

struct ExtensionControlAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

final class ExtensionManager: ObservableObject {
    @Published private(set) var enabledByID: [String: Bool] = [:]
    @Published private(set) var busyIDs: Set<String> = []
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
            var states: [String: Bool] = [:]
            var firstError: Error?

            for action in actions {
                do {
                    states[action.id] = try SystemExtensionController.isEnabled(action)
                } catch {
                    firstError = firstError ?? error
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.enabledByID.merge(states) { _, refreshed in refreshed }
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

        let previousValue = enabledByID[action.id] ?? !enabled
        enabledByID[action.id] = enabled
        busyIDs.insert(action.id)

        DispatchQueue.global(qos: .userInitiated).async {
            var actualValue = previousValue
            var operationError: Error?

            do {
                try SystemExtensionController.setEnabled(enabled, for: action)
                actualValue = try SystemExtensionController.isEnabled(action)
                guard actualValue == enabled else {
                    throw ExtensionControlError.stateDidNotChange(action.title)
                }
                try SystemExtensionController.reloadFinder()
            } catch {
                operationError = error
                actualValue = (try? SystemExtensionController.isEnabled(action)) ?? previousValue
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.enabledByID[action.id] = actualValue
                self.busyIDs.remove(action.id)
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
    private static let preferencesApplicationID = "pbs" as CFString
    private static let finderActiveKey = "FinderActive" as CFString

    static func isEnabled(_ action: FinderActionDescriptor) throws -> Bool {
        switch action.control {
        case .quickAction(let preferenceKey):
            CFPreferencesAppSynchronize(preferencesApplicationID)
            guard
                let dictionary = CFPreferencesCopyAppValue(
                    finderActiveKey,
                    preferencesApplicationID
                ) as? [String: Any],
                let value = dictionary[preferenceKey]
            else {
                return false
            }

            if let boolean = value as? Bool {
                return boolean
            }
            if let number = value as? NSNumber {
                return number.boolValue
            }
            return false

        case .finderSync:
            let output = try run(
                executable: "/usr/bin/pluginkit",
                arguments: ["-m", "-i", action.id]
            )
            guard let matchingLine = output
                .split(separator: "\n")
                .first(where: { $0.contains(action.id) })
            else {
                throw ExtensionControlError.extensionNotFound(action.title)
            }
            return matchingLine.trimmingCharacters(in: .whitespaces).hasPrefix("+")
        }
    }

    static func setEnabled(_ enabled: Bool, for action: FinderActionDescriptor) throws {
        switch action.control {
        case .quickAction(let preferenceKey):
            if enabled {
                try setPluginEnabled(true, bundleIdentifier: action.id)
                try setQuickActionEnabled(true, preferenceKey: preferenceKey)
            } else {
                try setQuickActionEnabled(false, preferenceKey: preferenceKey)
                try setPluginEnabled(false, bundleIdentifier: action.id)
            }

        case .finderSync:
            try setPluginEnabled(enabled, bundleIdentifier: action.id)
        }
    }

    static func reloadFinder() throws {
        _ = try? run(executable: "/usr/bin/killall", arguments: ["pbs"])
        _ = try run(executable: "/usr/bin/killall", arguments: ["Finder"])
    }

    private static func setQuickActionEnabled(_ enabled: Bool, preferenceKey: String) throws {
        CFPreferencesAppSynchronize(preferencesApplicationID)
        var dictionary = CFPreferencesCopyAppValue(
            finderActiveKey,
            preferencesApplicationID
        ) as? [String: Any] ?? [:]
        dictionary[preferenceKey] = enabled

        CFPreferencesSetAppValue(
            finderActiveKey,
            dictionary as CFDictionary,
            preferencesApplicationID
        )
        guard CFPreferencesAppSynchronize(preferencesApplicationID) else {
            throw ExtensionControlError.preferenceWriteFailed
        }
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
            return "系统尚未注册“\(title)”扩展。请重新打开超级右键后再试。"
        case .preferenceWriteFailed:
            return "无法保存 Finder 快速操作设置。"
        case .stateDidNotChange(let title):
            return "“\(title)”的系统状态没有发生变化。"
        }
    }
}
