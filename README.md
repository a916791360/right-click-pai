# 超级右键

一个仅供个人使用的原生 macOS 工具，为 Finder 提供三个右键动作：

- 拷贝路径：复制所选文件或文件夹的绝对路径，多选时每行一个。
- 隐藏已选项目：设置 macOS 原生隐藏标记，不移动或重命名项目。
- 取消隐藏当前文件夹内全部项目：由 Finder Sync 扩展提供，在文件夹空白处使用，恢复当前层中的非点号隐藏项目，不递归。

## 系统要求

- macOS 26 或更高版本
- Apple Silicon 或 Intel Mac
- 首次构建需要 Xcode 26

## 使用

1. 将 `超级右键.app` 放入 `/Applications`。
2. 打开 App；如需调整开关或顺序，点击“打开快速操作设置”。
3. 选中文件或文件夹后，在 Finder 右键菜单的“快速操作”中使用“拷贝路径”或“隐藏已选项目”。

隐藏文件或文件夹后，在当前 Finder 文件夹的空白处右键，执行“取消隐藏当前文件夹内全部项目”即可恢复。

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

拷贝和隐藏由 App 内嵌的 Action Extension 提供；空白处恢复由 Finder Sync Extension 提供。项目不联网，不包含分析、登录项或第三方依赖。
