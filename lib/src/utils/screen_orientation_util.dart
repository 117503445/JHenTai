import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// 屏幕方向工具类
/// 使用原生通道设置方向，绕过 Android 12L+ 大屏设备的 letterbox 问题
class ScreenOrientationUtil {
  static const _channel = MethodChannel('top.jtmonster.jjhentai.orientation');

  /// 设置为 nosensor 模式（忽略传感器，使用设备默认方向）
  /// 这是解决平板 letterbox 问题的关键
  static Future<void> setNosensor() async {
    if (!GetPlatform.isMobile) return;
    
    try {
      await _channel.invokeMethod('setOrientation', {'orientation': 'nosensor'});
    } catch (e) {
      // 降级到 Flutter API
      SystemChrome.setPreferredOrientations([]);
    }
  }

  /// 设置为横屏模式
  static Future<void> setLandscape() async {
    if (!GetPlatform.isMobile) return;
    
    try {
      await _channel.invokeMethod('setOrientation', {'orientation': 'landscapeAuto'});
    } catch (e) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// 设置为竖屏模式
  static Future<void> setPortrait() async {
    if (!GetPlatform.isMobile) return;
    
    try {
      await _channel.invokeMethod('setOrientation', {'orientation': 'portraitAuto'});
    } catch (e) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  /// 恢复默认方向（nosensor 模式）
  static Future<void> restore() async {
    await setNosensor();
  }
}
