import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// 屏幕方向工具类
/// 使用原生通道设置方向，绕过 Android 12L+ 大屏设备的 letterbox 问题
/// 
/// 注意：在小米平板等设备上，只有 nosensor 模式能绕过 letterbox
/// 因此所有方向设置都统一使用 nosensor 模式
class ScreenOrientationUtil {
  static const _channel = MethodChannel('top.jtmonster.jjhentai.orientation');

  /// 设置为 nosensor 模式（忽略传感器，使用设备默认方向）
  /// 这是解决平板 letterbox 问题的关键
  static Future<void> setNosensor() async {
    if (!GetPlatform.isMobile) return;
    
    try {
      await _channel.invokeMethod('setOrientation', {'orientation': 'nosensor'});
    } catch (e) {
      // 降级到 Flutter API - 清除方向限制
      SystemChrome.setPreferredOrientations([]);
    }
  }

  /// 设置为横屏模式
  /// 注意：为绕过平板 letterbox 问题，实际使用 nosensor 模式
  static Future<void> setLandscape() async {
    // 统一使用 nosensor 来绕过 letterbox
    await setNosensor();
  }

  /// 设置为竖屏模式
  /// 注意：为绕过平板 letterbox 问题，实际使用 nosensor 模式
  static Future<void> setPortrait() async {
    // 统一使用 nosensor 来绕过 letterbox
    await setNosensor();
  }

  /// 恢复默认方向（nosensor 模式）
  static Future<void> restore() async {
    await setNosensor();
  }
}
