import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var extensionManager = ExtensionManager()

    private let actions = [
        FinderActionDescriptor(
            id: "com.qingmeng.SuperRightClick.CopyPathAction",
            symbol: "link",
            title: "拷贝路径",
            detail: "复制完整路径，多选时每行一个",
            control: .quickAction(
                preferenceKey: "APPEXTENSION-com.qingmeng.SuperRightClick.CopyPathAction"
            )
        ),
        FinderActionDescriptor(
            id: "com.qingmeng.SuperRightClick.HideSelectedAction",
            symbol: "eye.slash",
            title: "隐藏已选项目",
            detail: "支持文件和文件夹",
            control: .quickAction(
                preferenceKey: "APPEXTENSION-com.qingmeng.SuperRightClick.HideSelectedAction"
            )
        ),
        FinderActionDescriptor(
            id: "com.qingmeng.SuperRightClick.CurrentFolderFinderSync",
            symbol: "eye",
            title: "取消隐藏当前文件夹内全部项目",
            detail: "恢复当前层的文件和文件夹",
            control: .finderSync
        )
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
        .onAppear {
            extensionManager.refresh(actions)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                extensionManager.refresh(actions)
            }
        }
        .alert(item: $extensionManager.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("好"))
            )
        }
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
                Text("三个轻量的 Finder 右键动作")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(appVersion)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private func actionRow(_ action: FinderActionDescriptor) -> some View {
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

            actionControl(action)
                .frame(width: 76, alignment: .trailing)
        }
        .frame(minHeight: 66)
        .padding(.horizontal, 20)
    }

    private var footer: some View {
        HStack {
            Text(footerStatus)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Button {
                extensionManager.refresh(actions)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(extensionManager.isRefreshing || !extensionManager.busyIDs.isEmpty)
            .help("刷新功能状态")

            Spacer()

            Button("打开快速操作设置") {
                openExtensionSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }

    @ViewBuilder
    private func actionControl(_ action: FinderActionDescriptor) -> some View {
        if let isEnabled = extensionManager.enabledState(for: action) {
            HStack(spacing: 8) {
                if extensionManager.isBusy(action) {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Color.clear
                        .frame(width: 16, height: 16)
                }

                Toggle(
                    action.title,
                    isOn: Binding(
                        get: { isEnabled },
                        set: { extensionManager.setEnabled($0, for: action) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(extensionManager.isBusy(action))
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(width: 52, height: 24)
        }
    }

    private var footerStatus: String {
        if extensionManager.isRefreshing {
            return "正在读取功能状态…"
        }
        let enabledCount = actions.filter {
            extensionManager.enabledState(for: $0) == true
        }.count
        return "\(enabledCount) 项已开启"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"
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
