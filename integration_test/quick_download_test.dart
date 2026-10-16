import 'package:integration_test/integration_test.dart';

import '../test/support/quick_download_cases.dart';

/// 在 Android 模拟器验证实际卡片的触摸区域及新版下载请求。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runQuickDownloadCases();
}
