import AppKit
import SwiftUI

struct ContentView: View {
    private let actions = [
        ActionDescriptor(symbol: "link", title: "拷贝路径", detail: "复制完整路径，多选时每行一个"),
        ActionDescriptor(symbol: "eye.slash", title: "隐藏已选项目", detail: "支持文件和文件夹"),
        ActionDescriptor(symbol: "eye", title: "取消隐藏文件夹内项目", detail: "仅处理所选文件夹的当前层")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            VStack(spacing: 0) {
                ForEach(actions) { action in
                    actionRow(action)
                    if action.id != actions.last?.id {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(.background)

            Divider()

            footer
        }
        .frame(width: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text("超级右键")
                    .font(.title2.weight(.semibold))
                Text("三个轻量的 Finder 快速操作")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("1.0")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private func actionRow(_ action: ActionDescriptor) -> some View {
        HStack(spacing: 14) {
            Image(systemName: action.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.body.weight(.medium))
                Text(action.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("已安装", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
        .frame(minHeight: 66)
        .padding(.horizontal, 20)
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("工作流已安装到 Finder 快速操作")
                    .font(.subheadline.weight(.medium))
                Text("可在系统设置中启用、停用或调整顺序")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("打开快速操作设置") {
                openExtensionSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }

    private func openExtensionSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.ExtensionsPreferences"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}

private struct ActionDescriptor: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}
