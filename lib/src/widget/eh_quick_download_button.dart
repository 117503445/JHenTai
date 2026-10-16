import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 画廊卡片共用的快捷下载入口。
class EHQuickDownloadButton extends StatelessWidget {
  /// [onPressed] 负责添加下载，[color] 沿用卡片文字颜色。
  const EHQuickDownloadButton({super.key, required this.onPressed, this.color});

  /// 点击下载时执行的动作。
  final VoidCallback onPressed;

  /// 图标颜色，留空时采用主题默认值。
  final Color? color;

  /// 根据 [context] 构建按钮。
  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: 'download'.tr,
        onPressed: onPressed,
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        visualDensity: VisualDensity.standard,
        icon: Icon(Icons.download_outlined, size: 24, color: color),
      ),
    );
  }
}
