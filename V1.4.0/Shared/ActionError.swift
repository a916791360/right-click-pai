import Foundation

enum SuperRightClickError: LocalizedError {
    case noInput
    case unsupportedInput
    case clipboardWriteFailed
    case foldersOnly
    case destinationMustBeFolder
    case alreadyInDestination(String)
    case destinationContainsItem(String)
    case cannotMoveIntoDescendant(String)
    case commandFailed(String)
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
        case .destinationMustBeFolder:
            return "请选择一个有效的目标文件夹。"
        case .alreadyInDestination(let name):
            return "“\(name)”已经在所选文件夹中。"
        case .destinationContainsItem(let name):
            return "目标文件夹中已存在名为“\(name)”的项目，未执行覆盖。"
        case .cannotMoveIntoDescendant(let name):
            return "不能将文件夹“\(name)”移动到它自身或它的子文件夹中。"
        case .commandFailed(let message):
            return message
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
