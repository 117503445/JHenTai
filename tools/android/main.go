// android 管理本项目独占的编译容器与模拟器容器，不修改宿主系统。
package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const builder = "jhentai-build-20261017"
const emulator = "jhentai-emulator-20261017"

// main 解析模式并执行对应容器操作。
func main() {
	mode := flag.String("mode", "test", "builder-image、builder、test、apk、emulator-image、emulator、verify")
	state := flag.String("state", "/workspace/codeclaw/projects/common/data/20261017-0209-jhentai", "本项目独占的运行目录")
	flag.Parse()
	root, err := os.Getwd()
	must(err)
	for _, dir := range []string{"artifacts", "logs", "cache", "cache/android", "tmp", "emulator"} {
		must(os.MkdirAll(filepath.Join(*state, dir), 0755))
	}
	policy := filepath.Join(*state, "policy.json")
	must(os.WriteFile(policy, []byte(`{"default":[{"type":"insecureAcceptAnything"}]}`), 0600))
	switch *mode {
	case "builder-image", "emulator-image":
		target := strings.TrimSuffix(*mode, "-image")
		podman(nil, "build", "--signature-policy", policy, "--network", "host", "--target", target,
			"-t", "localhost/jhentai-"+target+":20261017", "-f", "containers/android.Dockerfile", ".")
	case "builder":
		podman(nil, "run", "-d", "--name", builder, "--network", "host", "--http-proxy=false",
			"-v", root+":/workspace", "-v", *state+":/state", "-v", *state+"/cache/android:/root/.android", "-w", "/workspace",
			"-e", "PUB_CACHE=/state/cache/pub", "-e", "GRADLE_USER_HOME=/state/cache/gradle", "-e", "TMPDIR=/state/tmp",
			"localhost/jhentai-builder:20261017", "sleep", "infinity")
	case "test":
		buildExec("flutter", "pub", "get")
		args := append([]string{"flutter", "test"}, flag.Args()...)
		buildExec(args...)
	case "apk":
		buildExec("flutter", "build", "apk", "--verbose", "--debug", "--target", "lib/src/main.dart")
		copyFile("build/app/outputs/flutter-apk/app-debug.apk", filepath.Join(*state, "artifacts/JJHenTai-debug.apk"))
	case "emulator":
		args := []string{"run", "-d", "--name", emulator, "--network", "host", "--http-proxy=false",
			"--shm-size", "512m",
			"-v", *state + "/emulator:/state", "-e", "ANDROID_AVD_HOME=/state/android/avd", "-e", "ADB_SERVER_SOCKET=tcp:127.0.0.1:5039", "localhost/jhentai-emulator:20261017", "sleep", "infinity"}
		if _, err := os.Stat("/dev/kvm"); err == nil {
			args = append(args[:1], append([]string{"--device", "/dev/kvm"}, args[1:]...)...)
		}
		podman(nil, args...)
		if _, err := os.Stat(filepath.Join(*state, "emulator/android/avd/codeclaw.ini")); os.IsNotExist(err) {
			podman(strings.NewReader("no\n"), "exec", "-i", emulator, "avdmanager", "create", "avd", "-n", "codeclaw", "-k", "system-images;android-35;google_apis;x86_64", "-d", "pixel_2")
		} else {
			must(err)
		}
		configureDisplay(filepath.Join(*state, "emulator/android/avd/codeclaw.avd/config.ini"))
		accel := "off"
		if _, err := os.Stat("/dev/kvm"); err == nil {
			accel = "on"
		}
		podman(nil, "exec", "-d", emulator, "emulator", "-avd", "codeclaw", "-port", "5580", "-no-window", "-no-audio", "-no-boot-anim", "-no-snapshot", "-gpu", "swiftshader_indirect", "-accel", accel, "-memory", "2048", "-cores", "2")
	case "verify":
		buildExec("adb", "-P", "5039", "connect", "127.0.0.1:5581")
		deadline := time.Now().Add(15 * time.Minute)
		for {
			out, _ := exec.Command("podman", "exec", builder, "adb", "-P", "5039", "-s", "127.0.0.1:5581", "shell", "getprop", "sys.boot_completed").Output()
			if strings.TrimSpace(string(out)) == "1" {
				break
			}
			if time.Now().After(deadline) {
				panic("模拟器15分钟内未启动完成")
			}
			time.Sleep(5 * time.Second)
		}
		buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "shell", "input", "keyevent", "KEYCODE_WAKEUP")
		buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "shell", "wm", "dismiss-keyguard")
		// 测试环境预先完成系统全屏引导，并关闭系统转场动画。
		buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed")
		for _, animation := range []string{"window_animation_scale", "transition_animation_scale", "animator_duration_scale"} {
			buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "shell", "settings", "put", "global", animation, "0")
		}
		buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "install", "-r", "/state/artifacts/JJHenTai-debug.apk")
		// 为独占模拟器准备存储权限，避免首次授权页遮挡交互验证。
		buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "shell", "appops", "set", "top.jtmonster.jjhentai", "MANAGE_EXTERNAL_STORAGE", "allow")
		buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "shell", "am", "start", "-n", "top.jtmonster.jjhentai/.MainActivity")
		time.Sleep(15 * time.Second)
		buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "shell", "pidof", "top.jtmonster.jjhentai")
		captureBuild(filepath.Join(*state, "artifacts/startup.png"), "adb", "-P", "5039", "-s", "127.0.0.1:5581", "exec-out", "screencap", "-p")
		captureBuild(filepath.Join(*state, "logs/android-startup.log"), "adb", "-P", "5039", "-s", "127.0.0.1:5581", "logcat", "-d", "-t", "500")
		buildExec("flutter", "test", "integration_test/quick_download_test.dart", "-d", "127.0.0.1:5581")
		// 行为测试使用独立入口，完成后恢复真正的应用APK供人工查看。
		buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "install", "-r", "/state/artifacts/JJHenTai-debug.apk")
		buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "shell", "appops", "set", "top.jtmonster.jjhentai", "MANAGE_EXTERNAL_STORAGE", "allow")
		buildExec("adb", "-P", "5039", "-s", "127.0.0.1:5581", "shell", "am", "start", "-n", "top.jtmonster.jjhentai/.MainActivity")
	default:
		panic("未知模式：" + *mode)
	}
}

// buildExec 在独占编译容器中执行 args，并使用独立 ADB 服务端口。
func buildExec(args ...string) {
	podman(nil, append([]string{"exec", "-e", "ADB_SERVER_SOCKET=tcp:127.0.0.1:5039", builder}, args...)...)
}

// configureDisplay 在 iniPath 设置较低分辨率，减少软件模拟时的绘制开销。
func configureDisplay(iniPath string) {
	raw, err := os.ReadFile(iniPath)
	must(err)
	var lines []string
	for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
		key, _, _ := strings.Cut(line, "=")
		switch strings.TrimSpace(key) {
		case "hw.lcd.width", "hw.lcd.height", "hw.lcd.density":
			continue
		}
		lines = append(lines, line)
	}
	lines = append(lines, "hw.lcd.width=480", "hw.lcd.height=854", "hw.lcd.density=160")
	must(os.WriteFile(iniPath, []byte(strings.Join(lines, "\n")+"\n"), 0644))
}

// captureBuild 将编译容器执行 args 的输出保存到 destination。
func captureBuild(destination string, args ...string) {
	output, err := os.Create(destination)
	must(err)
	defer output.Close()
	cmd := exec.Command("podman", append([]string{"exec", builder}, args...)...)
	cmd.Stdout, cmd.Stderr = output, os.Stderr
	must(cmd.Run())
}

// podman 使用 input 作为标准输入执行 args，关闭继承的失效代理。
func podman(input io.Reader, args ...string) {
	cmd := exec.Command("podman", args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = input, os.Stdout, os.Stderr
	for _, entry := range os.Environ() {
		key := strings.ToLower(strings.SplitN(entry, "=", 2)[0])
		if key != "http_proxy" && key != "https_proxy" && key != "all_proxy" {
			cmd.Env = append(cmd.Env, entry)
		}
	}
	must(cmd.Run())
}

// copyFile 将 source 产物复制到 destination，不把构建产物放入版本控制。
func copyFile(source, destination string) {
	input, err := os.Open(source)
	must(err)
	defer input.Close()
	output, err := os.Create(destination)
	must(err)
	_, err = io.Copy(output, input)
	must(err)
	must(output.Close())
}

// must 在 err 非空时明确失败，避免把不完整构建报告为成功。
func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
