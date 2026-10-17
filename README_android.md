# Android 容器开发

当前 fork 在 CodeClaw 的 `projects/common/repos/JHenTai` 维护，origin 指向个人 fork，upstream 指向 `jiangtian616/JHenTai`。保留独立包名 `top.jtmonster.jjhentai`、下载页阅读进度及平板方向适配。

## 编译与验证

宿主需要 Go 1.26、Podman。以下命令在仓库根目录执行，不新增 go-task 任务。

CodeClaw 当前环境可先用 `nix shell nixpkgs#go nixpkgs#podman` 进入工具环境。

Y9000P NixOS WSL 为后续编译与设备验证环境，源码位于 `/home/nixos/projects/jhentai/repos/JHenTai`，运行目录为 `/home/nixos/projects/jhentai/data/android`。在该源码目录使用 `nixos` 用户运行下述命令时，附加 `-state /home/nixos/projects/jhentai/data/android`。首次环境配置由 NixOP 的 `assets/nodes/y9000p-nixos/jhentai-dev.json` 管理。CodeClaw 保留维护记录，源码变更继续推送个人 fork；两处源码通过 Git 同步。

已有本任务容器运行时，直接执行 `test`、`apk` 或 `verify`；仅在首次创建时执行镜像构建和容器创建步骤。

```console
go run tools/android/main.go -mode builder-image
go run tools/android/main.go -mode builder
go run tools/android/main.go -mode test
go run tools/android/main.go -mode apk
go run tools/android/main.go -mode emulator-image
go run tools/android/main.go -mode emulator
```

`emulator` 在容器内后台运行，启动后执行：

```console
go run tools/android/main.go -mode verify
```

- 镜像使用 Flutter 3.44.8、Android SDK 36、NDK 28.2.13676358，模拟器使用 Android 35；没有 `/dev/kvm` 时使用软件模拟。
- 编译容器和模拟器容器分别独占源码/缓存和虚拟设备状态，不依赖其他任务的容器。编译缓存、APK、日志和虚拟设备位于工具 `-state` 指定的目录，默认是 CodeClaw 本任务 data 目录。
- `apk` 产出调试签名 APK，适合验证，不是正式发布包。正式发布沿用 GitHub Actions，不手工创建 release。
- Flutter 的 ARM64 分包自动给上游编号加 2000，例如 337 对应 2337，延续已安装旧版 2306；Gradle 中不重复添加偏移。正式包必须使用原有签名；安装前备份旧 APK 并核对证书，使用覆盖升级保留数据。
- 模拟器使用独立端口5580/5581、ADB服务5039，避免操作其他设备。
- 行为用例使用本地生成的中性封面、真实画廊卡片及快捷下载逻辑，记录发往下载引擎的请求，不访问真实画廊或使用账号；验证点击区域、边缘点击、默认分组、非原图和重复下载拦截。
- 软件模拟不适合性能验收，当前两核环境曾出现系统组件ANR；设备测试结果须与该环境限制一起解读。
- 当前 `Dockerfile`、`build-by-docker.sh` 等是旧构建入口；新环境使用 `containers/android.Dockerfile` 和上述 Go 工具。

## 同步上游

Rebase 前保留已推送的备份分支；处理新版下载引擎接口及卡片布局冲突后，运行测试并构建 APK。更新 fork 使用带明确旧提交的 `--force-with-lease`，提交后立即推送。
