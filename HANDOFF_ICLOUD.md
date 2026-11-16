# iCloud YAML 同步：本地接续记录

更新时间：2026-11-16。供在本地 Mac 上打开此仓库的 Codex 接续工作。

## 当前进度

**功能代码已实现并推送，尚未完成 Flutter 编译、测试和 macOS/iCloud 实机验证。下一步是验证和修复，不是重新设计功能。**

- 仓库：`https://github.com/mashpolo/FlClash`
- 工作分支：`feat/icloud-yaml-sync`
- 功能提交：`cee98d2a8ae7f4aec3998bef4f31a752b4ea6e99`
- 用户计划在本地 `~/work/FlClash-icloud` 继续；以实际打开的仓库路径为准。
- 分支已推送；本轮未创建 PR，也未合并到 `main`。
- 云端工作区和下载包不是本地接续的依赖，直接使用该 Git 分支。

## 用户已确定的需求

1. macOS 用户选择 iCloud Drive 文件夹，不使用应用专属 iCloud 容器。
2. 仅同步 Clash YAML 配置文件，不同步应用设置或订阅元数据。
3. 自动双向同步，冲突时由用户选择版本。

实现的具体行为和使用方式见 [macos/ICLOUD_SYNC.md](macos/ICLOUD_SYNC.md)。
当前实现每 30 秒检查一次，只在应用运行时同步；删除不跨设备传播。
加密配置和从数据库生成的自定义配置不参与同步，文件重命名作为新文件处理。
这些是当前实现边界，不要自行扩展成 iOS、CloudKit、完整备份或删除传播功能。

## 代码位置

| 文件 | 职责 |
| --- | --- |
| `lib/features/icloud/reconcile.dart` | 根据共同基线和两端内容哈希判断上传、下载、冲突或缺失 |
| `lib/features/icloud/sync.dart` | 轮询、文件身份映射、本机同步记录、校验和应用下载内容 |
| `lib/features/icloud/section.dart` | 文件夹选择、开关、同步状态和冲突选择 UI |
| `lib/application.dart` | 启动同步、前台冲突提示、退出时停止 |
| `lib/views/backup_and_restore.dart` | macOS 的 iCloud 功能入口 |
| `macos/Runner/ICloudFolder.swift` | 文件夹选择、安全作用域书签、协调读写、下载占位文件处理 |
| `macos/Runner/MainFlutterWindow.swift` | 注册 `flclash/icloud` MethodChannel |
| `macos/Runner.xcodeproj/project.pbxproj` | 注册新增 Swift 源文件 |
| `macos/Runner/*.entitlements` | 增加应用作用域书签权限 |
| `test/features/icloud/` | 12 个新增测试：决策、同步流程和 UI 状态 |

## 已做与未做的验证

已完成：

- Dart 和 Swift 的 Tree-sitter 语法解析，无解析错误。
- 两份 entitlements 的 plist 解析，以及 Xcode 源文件注册引用检查。
- `git diff --check`、注释密度和提交消息格式检查。
- Dart 修改通过外部 WASM `dart_style` 格式化器处理；仍需本地官方 `dart format` 验证。
- 对同步逻辑、平台读写、UI 和应用生命周期接入做了结构检查，未提出阻止提交的结构问题。

**没有完成，不能描述为通过：**

- `flutter pub get --enforce-lockfile`
- `flutter analyze --no-fatal-infos`
- `flutter test test/features/icloud/ test/views/backup_and_restore_test.dart`
- macOS 构建、应用启动及双机 iCloud 验证

上述 Flutter 命令在云端都停在 Dart SDK 下载阶段：网络策略拒绝 `storage.googleapis.com`，HTTP 403。
没有测试实际执行。云端是 Linux，也不能构建 macOS；语法解析不提供类型检查或平台 API 正确性保证。
前期环境设置中通过的 Rust/Git hook 测试不构成本功能验证。
不要尝试激活旧文档中的 `/workspace/toolchains` 路径，它们仅存在于云端。

## 本地接续顺序

先阅读 `AGENTS.md` 和 `.agents/project.md`、`.agents/commands.md`、`.agents/rules.md`。
检查工作目录和用户已有改动，保留本地修改；不要重置分支或覆盖本地工作。

在已克隆的仓库中：

```sh
cd ~/work/FlClash-icloud
git status --short --branch
git pull --ff-only
git -c url.https://github.com/.insteadOf=git@github.com: submodule update --init --recursive
```

确认当前分支为 `feat/icloud-yaml-sync`。如果用户打开的是其他目录或其他分支，先核对再操作。

检查工具链，优先使用已安装且符合仓库版本要求的工具：

- Flutter `3.47.6`：以 `.github/workflows/build.yaml` 为准，Dart 由 Flutter 提供。
- Go `1.27.1`：构建 hook 会用到。
- Rust `1.99.0`：以 `plugins/rust_api/rust/rust-toolchain.toml` 为准，需 `cargo` / `rustc` 可用。
- 完整 Xcode 和 macOS SDK；CI 使用 Xcode 26.3，26.2 为回退。检查 `xcode-select -p`、`xcodebuild -version`。
- 先用 `flutter doctor -v` 诊断缺项，再安装所需工具。不要为了通过测试改 SDK 版本约束或关闭构建 hook。

从仓库根目录按顺序执行：

```sh
flutter --version
go version
rustup run 1.99.0 rustc --version
flutter doctor -v
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib/application.dart lib/views/backup_and_restore.dart lib/features/icloud test/features/icloud
flutter analyze --no-fatal-infos
flutter test test/features/icloud/ test/views/backup_and_restore_test.dart
flutter build macos --debug --dart-define=SAFE_MODE=true
flutter run -d macos --dart-define=SAFE_MODE=true
```

遇到失败先读实际输出并修复当前功能或环境，再重跑受影响检查。
重点核查 Swift/API 编译、MethodChannel 数据类型、持久化恢复、并发写入和退出清理；目前没有实机证据证明这些路径已通过。
不要用删除测试、放宽断言、手改生成代码或禁用 hook 来绕过失败。

## 实机验收

使用专用测试文件夹和可丢弃的 YAML 配置。在登录同一 iCloud 账号的两台 Mac 上检查：

1. 首次选择目录后本地 YAML 导出；另一台 Mac 导入同一文件且不重复创建配置。
2. 仅修改本地或仅修改云端，分别同步到另一端，导入配置经过现有 Core 校验。
3. 双方离线修改同一文件后上线，自动提示冲突；分别测试两个方向的选择和关闭弹窗。
4. 弹窗打开后再次修改文件，旧选择不覆盖新内容。
5. 重启应用后目录授权与同步基线恢复。
6. 取消目录选择、断网、尚未下载的 iCloud 文件、无效 YAML 和写入失败均不破坏现有文件。
7. 删除一端文件时暂停该文件，不传播删除；关闭同步后不再复制。
8. 应用退出或同步期间停止时，不留下持续运行的同步任务。

只有一台 Mac 时先完成编译、测试和单机路径，明确记录双机部分仍未验证。
遵守仓库要求：代理只能启动 `SAFE_MODE=true` 的应用；记录自己启动的 PID，仅结束这些进程，不能按名称杀进程。
安全模式不替代对同步测试文件的隔离。不要操作用户正在使用的真实配置来做破坏性验证。

## 给本地 Codex 的任务

继续完成本分支的本地验证和必要修复。每完成一步，将实际结果、失败原因和下一步更新到本文档，
区分通过、失败、阻塞和未执行；不要把现有代码默认当作已验证。
完成后报告测试结果、macOS 启动结果及剩余实机限制。
如需提交后续修复，遵守仓库提交规范和当前用户授权；不得自动合并到 main。
