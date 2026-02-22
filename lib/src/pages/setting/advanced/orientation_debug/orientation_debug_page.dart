import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrientationDebugPage extends StatefulWidget {
  const OrientationDebugPage({Key? key}) : super(key: key);

  @override
  State<OrientationDebugPage> createState() => _OrientationDebugPageState();
}

class _OrientationDebugPageState extends State<OrientationDebugPage> {
  String _currentMode = '无';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('屏幕方向调试'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '当前模式: $_currentMode',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                
                // 横屏模式
                _buildSectionTitle('横屏模式'),
                _buildButton('横屏 (右旋)', () => SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight])),
                _buildButton('横屏 (左旋)', () => SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft])),
                _buildButton('横屏自动', () => SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight])),
                
                const SizedBox(height: 16),
                
                // 竖屏模式
                _buildSectionTitle('竖屏模式'),
                _buildButton('竖屏 (正向)', () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])),
                _buildButton('竖屏 (反向)', () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitDown])),
                _buildButton('竖屏自动', () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown])),
                
                const SizedBox(height: 16),
                
                // 全自动模式
                _buildSectionTitle('全自动模式'),
                _buildButton('全自动', () => SystemChrome.setPreferredOrientations(DeviceOrientation.values)),
                
                const SizedBox(height: 16),
                
                // 用户配置模式
                _buildSectionTitle('其他模式'),
                _buildButton('清除方向限制', () => SystemChrome.setPreferredOrientations([])),
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
        },
        child: Text(buttonText, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
