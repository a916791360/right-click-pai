# 右键派

<p align="center">
  <img src="Design/AppIcon.png" width="128" alt="右键派图标">
</p>

一个开源、轻量的原生 macOS Finder 右键工具。右键派只做五件事，并且每项功能都可以独立开启或关闭。

## 功能

- **拷贝路径**：复制所选文件或文件夹的绝对路径；多选时每行一个，方便粘贴到文本编辑器或终端。
- **移动到**：为所选文件或文件夹选择目标文件夹并立即移动；遇到同名项目时不会覆盖。
- **隐藏已选项目**：使用 macOS 原生隐藏标记隐藏文件或文件夹，不移动、不改名、不删除。
- **取消隐藏当前文件夹内全部项目**：在 Finder 文件夹空白处右键，恢复当前层被隐藏的普通项目；不递归处理子目录，也不会显示以 `.` 开头的系统或配置文件。
- **进入终端**：选中文件夹后直接打开“终端”并进入该目录；选中文件时进入其所在目录。多选时每个目录各开一个终端窗口，不用再把文件夹拖进终端。

关闭 App 中的某个开关后，对应动作会从 Finder 右键菜单中消失。

## 下载和安装

从 [Releases](https://github.com/a916791360/right-click-pai/releases/latest) 下载最新的 `RightClickPai-v1.4.0-Apple-Silicon.zip`：

1. 解压后，将 `右键派.app` 拖入“应用程序”文件夹。
2. 第一次打开时，如果 macOS 提示无法验证开发者，请在 Finder 中右键 App，选择“打开”，再确认一次；也可以前往“系统设置 → 隐私与安全性”选择“仍要打开”。
3. 打开右键派，用五个开关控制 Finder 菜单中的功能。
4. 如果菜单没有立即出现，请在“系统设置 → 通用 → 登录项与扩展”中确认 Finder 扩展已启用，然后重新打开 Finder。

从 1.2.0 或更早版本升级时，请先退出并移除旧名称的“超级右键.app”，再安装“右键派.app”，避免 macOS 同时缓存两个同 Bundle Identifier 的版本。

> 当前下载包采用本地临时签名，没有经过 Apple Developer ID 公证，因此首次运行会出现上述系统安全提示。项目不尝试绕过 macOS 安全机制。

## 系统要求

- Apple Silicon Mac：M1、M2、M3、M4 或后续 M 系列芯片
- macOS 15 或更高版本
- 不支持 Intel Mac

这个版本在 Apple Silicon Mac 上构建，发行包中的主程序和 Finder 扩展均为 `arm64`。

## 使用说明

选中文件或文件夹，可以直接在 Finder 右键菜单中使用“拷贝路径”“移动到…”“隐藏已选项目”或“进入终端”。动作相邻显示，不需要再进入“快速操作”子菜单。

使用“移动到…”时，macOS 会显示系统文件夹选择窗口。选择目标文件夹并点击“移动”后才会执行；如果系统询问桌面、文稿、下载或外接磁盘访问权限，请按需授权。右键派不会覆盖目标文件夹中的同名项目。

使用“进入终端”时，选中文件夹会直接在该文件夹打开一个“终端”窗口；选中文件会在文件所在目录打开。多选时每个目录各开一个窗口。首次使用“进入终端”时，macOS 可能询问是否允许右键派打开其他应用，请允许。

项目隐藏后无法再直接右键选中它。恢复时，在它原来所在文件夹的空白处右键，选择“取消隐藏当前文件夹内全部项目”。这个操作只恢复当前文件夹这一层，避免意外改动整个目录树。

右键派覆盖用户主目录、桌面、下载、文稿、iCloud Drive、外接硬盘和 U 盘中的普通可写目录。它不保证支持网络共享盘，也不会尝试修改 macOS 受保护的系统目录；权限不足时会直接报告错误。

## 隐私

- 不联网
- 不收集数据
- 不包含统计分析或登录功能
- 不包含第三方依赖
- 所有文件操作都在本机完成

## 从源码构建

需要 Xcode 26。克隆项目后运行：

```bash
git clone https://github.com/a916791360/right-click-pai.git
cd right-click-pai
xcodebuild \
  -project SuperRightClick.xcodeproj \
  -scheme SuperRightClick \
  -configuration Release \
  -derivedDataPath ./DerivedData \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=YES \
  build
```

构建结果位于 `DerivedData/Build/Products/Release/右键派.app`。

运行测试：

```bash
xcodebuild \
  -project SuperRightClick.xcodeproj \
  -scheme SuperRightClick \
  -configuration Debug \
  -derivedDataPath ./DerivedData \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=YES \
  test
```

## 技术说明

五项菜单均由同一个 Finder Sync Extension 提供。选中文件时显示“拷贝路径”“移动到…”“隐藏已选项目”和“进入终端”；在文件夹空白处右键时显示“取消隐藏当前文件夹内全部项目”。主 App 通过共享配置控制每项菜单是否出现。

“移动到…”由 Finder 扩展创建一次性本地请求，再唤起主 App 显示系统文件夹选择窗口并执行移动。“进入终端”同样由 Finder 扩展创建一次性本地请求，再唤起主 App 打开“终端”并进入对应目录。请求只保存在当前用户的 Application Support 目录，不会上传或发送到外部服务。

Finder 决定扩展菜单在右键菜单中的最终分组和位置；macOS 更新或其他 Finder 扩展可能影响显示顺序。

为保证从旧版平滑升级，代码中的 `SuperRightClick` 工程名和 Bundle Identifier 暂时保留；用户看到的产品名称及构建产物均为“右键派”。

## 参与贡献

欢迎提交 Issue 或 Pull Request。修改文件操作逻辑时，请同时补充对应测试，并确认不会递归处理用户未选择的目录。

## 许可证

本项目使用 [MIT License](LICENSE)。
