import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 画廊卡片共用的快捷下载入口。
class EHQuickDownloadButton extends StatelessWidget {
  /// [onPressed] 负责添加下载，[color] 可覆盖主题图标颜色。
  const EHQuickDownloadButton({super.key, required this.onPressed, this.color});

  /// 点击下载时执行的动作。
  final VoidCallback onPressed;

  /// 图标颜色，留空时采用主题默认值。
  final Color? color;

  /// 根据 [context] 构建按钮。
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 48,
      child: Material(
        color: Colors.transparent,
        child: IconButton(
          tooltip: 'download'.tr,
          onPressed: onPressed,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          visualDensity: VisualDensity.standard,
          iconSize: 40,
          icon: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh.withValues(alpha: 0.96),
              shape: BoxShape.circle,
              border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.download_rounded,
                size: 24, color: color ?? colors.primary),
          ),
        ),
      ),
    );
  }
}
