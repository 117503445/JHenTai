import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/widget/eh_quick_download_button.dart';

/// 验证快捷下载的触摸区域以及它与卡片点击之间的手势隔离。
void main() {
  testWidgets('快捷下载至少48dp，点击边缘只触发下载', (tester) async {
    var downloads = 0;
    var details = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          onTap: () => details++,
          child: Center(
            child: EHQuickDownloadButton(onPressed: () => downloads++),
          ),
        ),
      ),
    ));

    final button = find.byType(EHQuickDownloadButton);
    final rect = tester.getRect(button);
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(tester.widget<Icon>(find.byIcon(Icons.download_rounded)).size,
        greaterThanOrEqualTo(24));
    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    await tester.pump();
    expect(downloads, 1);
    expect(details, 0);
    expect(find.byTooltip('download'), findsOneWidget);
  });
}
