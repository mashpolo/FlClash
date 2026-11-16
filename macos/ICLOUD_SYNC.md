# iCloud Drive YAML 同步（macOS）

在「工具 → 备份与恢复 → iCloud Drive · YAML」选择 iCloud Drive 中的专用文件夹。
同一 Apple 账号的其他 Mac 选择相同文件夹，FlClash 运行期间每 30 秒检查一次；点击「同步」可立即检查。
选择目录即启用，关闭「已启用」开关停止同步并清除本机目录授权，不会删除本地或云端文件。

仅同步文件配置、订阅下载后的原始 YAML；不上传订阅 URL 元数据、数据库、应用设置、日志或缓存。
数据库生成的自定义配置和带解密密钥的加密配置不参与同步。
原始 YAML 内已有的字段保持原样。云端文件默认以本地配置 ID 命名；可导入目录顶层的 `.yaml` / `.yml` 文件。
导入到另一台 Mac 后成为文件配置，文件名与该设备配置 ID 的关联只保存在本机。
请保持文件名稳定；更名被视为新文件，不会自动合并配置。

同步使用上一次成功同步的内容哈希作为共同基线：

- 仅一端改变：自动复制到另一端。
- 两端都改变，或首次同步已有不同内容：不覆盖，在前台弹出选择框。
- 「本地 → 远程」使用本地内容；「远程 → 本地」使用云端内容。
- 关闭选择框会保留两端，稍后可在 iCloud 区域点击对应文件继续选择。
- 选择后若内容再次发生变化，该选择失效，重新显示冲突。
- 文件删除不跨设备传播。已同步文件有一端缺失时暂停该文件，显示「本地 / 远程：暂无信息」；恢复缺失文件后重试。

macOS 负责实际上传到 iCloud；本地写入成功不代表另一台设备已经收到。
尚未下载的文件会请求系统下载并稍后重试，读取失败不当作空文件覆盖。
Finder 报告的 iCloud 多版本冲突需先在 Finder 中解决。
单文件上限 16 MiB，不递归同步子目录，不跟随文件符号链接。

## 验证

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-fatal-infos
flutter test test/features/icloud/ test/views/backup_and_restore_test.dart
flutter build macos --debug --dart-define=SAFE_MODE=true
flutter run -d macos --dart-define=SAFE_MODE=true
```

在两台已登录 iCloud 的 Mac 上验证首次导出/导入、单向修改、双方离线修改后的冲突选择、
目录授权跨重启、取消目录选择、下载中和断网重试、删除暂停、禁用后不再复制。
关闭应用后不会继续同步。无需应用专属 iCloud 容器。

本次云端实现环境是 Linux，Flutter 的 Dart 组件下载被网络策略阻断；上述 Flutter 测试、
macOS 编译与两机 iCloud 验证尚未执行。语法解析检查不能替代这些验证。
