import Foundation

enum SuperRightClickError: LocalizedError {
    case noInput
    case unsupportedInput
    case clipboardWriteFailed
    case foldersOnly
    case partialFailure(action: String, failures: [(URL, Error)])

    var errorDescription: String? {
        switch self {
        case .noInput:
            return "Finder 没有提供可处理的项目。"
        case .unsupportedInput:
            return "无法读取 Finder 传入的文件路径。"
        case .clipboardWriteFailed:
            return "无法写入系统剪贴板。"
        case .foldersOnly:
            return "此操作只能用于文件夹。"
        case let .partialFailure(action, failures):
            let first = failures[0]
            let detail = first.1.localizedDescription
            if failures.count == 1 {
                return "\(action)失败：\(first.0.lastPathComponent)（\(detail)）"
            }
            return "\(action)有 \(failures.count) 个项目失败。首个失败项目：\(first.0.lastPathComponent)（\(detail)）"
        }
    }
}
