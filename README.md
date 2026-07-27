# 超级右键

一个仅供个人使用的原生 macOS 工具，为 Finder 提供三个快速操作：

- 拷贝路径：复制所选文件或文件夹的绝对路径，多选时每行一个。
- 隐藏已选项目：设置 macOS 原生隐藏标记，不移动或重命名项目。
- 取消隐藏文件夹内项目：恢复所选文件夹当前层中的非点号隐藏项目，不递归。

## 系统要求

- macOS 26 或更高版本
- Apple Silicon 或 Intel Mac
- 首次构建需要 Xcode 26

## 使用

1. 将 `超级右键.app` 放入 `/Applications`。
2. 运行 `Tools/install_workflows.sh`，把三个工作流安装到当前用户的 `~/Library/Services`。
3. 打开 App；如需调整开关或顺序，点击“打开快速操作设置”。
4. 在 Finder 中选中文件或文件夹，右键打开“快速操作”。

“取消隐藏文件夹内项目”只在选中文件夹时出现。要恢复某个文件夹中的隐藏项目，请在其上一级目录选中该文件夹后执行。

## 构建

```bash
xcodebuild \
  -project SuperRightClick.xcodeproj \
  -scheme SuperRightClick \
  -configuration Release \
  -derivedDataPath ./DerivedData \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=YES \
  build
```

构建结果位于：

```text
DerivedData/Build/Products/Release/SuperRightClick.app
```

## 测试

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

快速操作采用 macOS 自带的 Automator 工作流，收到的是 Finder 原始路径，不处理临时副本。项目不联网，不包含分析、后台服务、登录项或第三方依赖。
