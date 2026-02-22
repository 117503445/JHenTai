import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrientationDebugPage extends StatefulWidget {
  const OrientationDebugPage({Key? key}) : super(key: key);

  @override
  State<OrientationDebugPage> createState() => _OrientationDebugPageState();
}

class _OrientationDebugPageState extends State<OrientationDebugPage> {
  static const _orientationChannel = MethodChannel('top.jtmonster.jjhentai.orientation');
  
  String _currentMode = '无';
  Map<String, dynamic>? _screenInfo;
  Map<String, dynamic>? _letterboxStatus;
  String _lastError = '';

  @override
  void initState() {
    super.initState();
    _refreshAllInfo();
  }

  Future<void> _refreshAllInfo() async {
    await Future.wait([
      _refreshScreenInfo(),
      _refreshLetterboxStatus(),
    ]);
  }

  Future<void> _refreshScreenInfo() async {
    try {
      final info = await _orientationChannel.invokeMethod('getScreenInfo');
      setState(() {
        _screenInfo = Map<String, dynamic>.from(info);
      });
    } catch (e) {
      setState(() {
        _lastError = 'ScreenInfo: $e';
      });
    }
  }

  Future<void> _refreshLetterboxStatus() async {
    try {
      final status = await _orientationChannel.invokeMethod('getLetterboxStatus');
      setState(() {
        _letterboxStatus = Map<String, dynamic>.from(status);
        _lastError = '';
      });
    } catch (e) {
      setState(() {
        _lastError = 'LetterboxStatus: $e';
      });
    }
  }

  Future<void> _forceFullscreen() async {
    try {
      await _orientationChannel.invokeMethod('forceFullscreen');
      setState(() {
        _currentMode = '强制全屏';
        _lastError = '';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      await _refreshAllInfo();
    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });
    }
  }

  Future<void> _setNativeOrientation(String orientation) async {
    try {
      await _orientationChannel.invokeMethod('setOrientation', {'orientation': orientation});
      setState(() {
        _currentMode = '原生: $orientation';
        _lastError = '';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      await _refreshAllInfo();
    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final hasLetterbox = _letterboxStatus?['hasLetterbox'] ?? false;
    
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('屏幕方向调试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllInfo,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Letterbox 状态警告
                if (hasLetterbox)
                  Card(
                    color: Colors.red.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('检测到 Letterbox!', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                                Text('窗口未铺满全屏', style: TextStyle(color: Colors.red.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // 当前状态信息
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('当前模式: $_currentMode', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Flutter尺寸: ${mediaQuery.size.width.toInt()} x ${mediaQuery.size.height.toInt()}'),
                        Text('像素比: ${mediaQuery.devicePixelRatio.toStringAsFixed(2)}'),
                        Text('方向: ${mediaQuery.orientation == Orientation.landscape ? "横屏" : "竖屏"}'),
                        if (_screenInfo != null) ...[
                          const Divider(),
                          Text('原生屏幕信息:', style: Theme.of(context).textTheme.titleSmall),
                          Text('API Level: ${_screenInfo!['apiLevel']}'),
                          Text('旋转: ${_screenInfo!['rotation']} (0=0°, 1=90°, 2=180°, 3=270°)'),
                          Text('是否横屏: ${_screenInfo!['isLandscape']}'),
                          Text('屏幕: ${_screenInfo!['screenWidthDp']} x ${_screenInfo!['screenHeightDp']} dp'),
                          Text('最小宽度: ${_screenInfo!['smallestScreenWidthDp']} dp'),
                          Text('是否平板: ${_screenInfo!['isTablet']}'),
                          Text('当前方向设置: ${_screenInfo!['currentOrientation']}'),
                        ],
                        if (_letterboxStatus != null) ...[
                          const Divider(),
                          Text('Letterbox 检测:', style: Theme.of(context).textTheme.titleSmall),
                          Text('设备: ${_letterboxStatus!['manufacturer']} ${_letterboxStatus!['model']}'),
                          Text('显示器: ${_letterboxStatus!['displayWidth']} x ${_letterboxStatus!['displayHeight']} px'),
                          Text('内容区: ${_letterboxStatus!['contentWidth']} x ${_letterboxStatus!['contentHeight']} px'),
                          Text('装饰区: ${_letterboxStatus!['decorWidth']} x ${_letterboxStatus!['decorHeight']} px'),
                          Text('有Letterbox: ${_letterboxStatus!['hasLetterbox']}', 
                            style: TextStyle(
                              color: _letterboxStatus!['hasLetterbox'] == true ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        if (_lastError.isNotEmpty) ...[
                          const Divider(),
                          Text('错误: $_lastError', style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 强制全屏按钮
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  onPressed: _forceFullscreen,
                  child: const Text('强制全屏 (重试禁用 Letterbox)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                
                const SizedBox(height: 16),
                
                // 原生方向控制 (绕过 letterbox)
                _buildSectionTitle('原生方向控制 (尝试绕过 Letterbox)'),
                _buildNativeButton('竖屏 (正向)', 'portraitUp'),
                _buildNativeButton('竖屏 (反向)', 'portraitDown'),
                _buildNativeButton('竖屏自动', 'portraitAuto'),
                _buildNativeButton('用户竖屏', 'userPortrait'),
                _buildNativeButton('横屏 (左旋)', 'landscapeLeft'),
                _buildNativeButton('横屏 (右旋)', 'landscapeRight'),
                _buildNativeButton('横屏自动', 'landscapeAuto'),
                _buildNativeButton('用户横屏', 'userLandscape'),
                _buildNativeButton('全自动 (fullSensor)', 'auto'),
                _buildNativeButton('用户控制 (user)', 'user'),
                _buildNativeButton('完全用户控制 (fullUser)', 'fullUser'),
                _buildNativeButton('跟随后台 (behind)', 'behind'),
                _buildNativeButton('忽略传感器 (nosensor)', 'nosensor'),
                _buildNativeButton('锁定当前 (locked)', 'locked'),
                _buildNativeButton('系统默认 (unspecified)', 'unspecified'),
                
                const SizedBox(height: 16),
                
                // Flutter 方向控制
                _buildSectionTitle('Flutter 方向控制 (可能触发 Letterbox)'),
                _buildButton('横屏 (右旋)', () => SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight])),
                _buildButton('横屏 (左旋)', () => SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft])),
                _buildButton('横屏自动', () => SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight])),
                
                const SizedBox(height: 8),
                
                _buildButton('竖屏 (正向)', () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])),
                _buildButton('竖屏 (反向)', () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitDown])),
                _buildButton('竖屏自动', () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown])),
                
                const SizedBox(height: 8),
                
                _buildButton('全自动', () => SystemChrome.setPreferredOrientations(DeviceOrientation.values)),
                _buildButton('清除方向限制', () => SystemChrome.setPreferredOrientations([])),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNativeButton(String buttonText, String orientation) {
    final bool isActive = _currentMode == '原生: $orientation';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: isActive ? Colors.orange : Colors.deepPurple,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        onPressed: () => _setNativeOrientation(orientation),
        child: Text(buttonText, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildButton(String buttonText, VoidCallback onPressed) {
    final bool isActive = buttonText == _currentMode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: isActive ? Colors.green : Theme.of(context).colorScheme.primary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        onPressed: () {
          setState(() {
            _currentMode = buttonText;
          });
          onPressed();
          Future.delayed(const Duration(milliseconds: 500), _refreshAllInfo);
        },
        child: Text(buttonText, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
