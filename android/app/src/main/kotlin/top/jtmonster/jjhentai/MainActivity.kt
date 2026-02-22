package top.jtmonster.jjhentai

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.Surface
import android.view.View
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {
    private var interceptVolumeEvent = false
    private lateinit var volumeMethodChannel: MethodChannel
    private lateinit var orientationMethodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        volumeMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "top.jtmonster.jjhentai.volume.event.intercept"
        )

        volumeMethodChannel.setMethodCallHandler { call, result ->
            if (call.method == "set") {
                val value = call.arguments<Boolean>()
                if (value != null) {
                    interceptVolumeEvent = value
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // 屏幕方向控制通道
        orientationMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "top.jtmonster.jjhentai.orientation"
        )

        orientationMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setOrientation" -> {
                    val orientation = call.argument<String>("orientation")
                    setScreenOrientation(orientation)
                    result.success(null)
                }
                "getScreenInfo" -> {
                    result.success(getScreenInfo())
                }
                "forceFullscreen" -> {
                    forceFullscreen()
                    result.success(null)
                }
                "getLetterboxStatus" -> {
                    result.success(getLetterboxStatus())
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false)

        // 禁用 Android 12L+ 的 letterbox 行为
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Disable the Android splash screen fade out animation
            splashScreen.setOnExitAnimationListener { splashScreenView -> splashScreenView.remove() }
        }

        // Android 12+ 大屏设备适配：禁用强制 letterbox
        disableLetterboxing()

        super.onCreate(savedInstanceState)
        
        // 强制全屏并设置默认方向为 nosensor（解决平板 letterbox 问题）
        forceFullscreen()
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_NOSENSOR
    }

    /**
     * 强制全屏显示，隐藏系统栏
     */
    private fun forceFullscreen() {
        try {
            val controller = WindowInsetsControllerCompat(window, window.decorView)
            controller.hide(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            
            // 设置全屏标志
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
            
            window.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
            window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
            
            // 设置窗口属性以扩展到安全区域外
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                window.attributes.layoutInDisplayCutoutMode = 
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * 禁用 letterbox 模式，确保应用铺满全屏
     */
    private fun disableLetterboxing() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                // 设置窗口标志，确保全屏显示
                window.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
                
                // 方法1: 使用反射禁用 letterbox (针对 Android 12L+)
                if (Build.VERSION.SDK_INT >= 32) { // Android 12L = API 32
                    try {
                        val activityClass = android.app.Activity::class.java
                        val method = activityClass.getDeclaredMethod(
                            "setIgnoreOrientationRequest", 
                            Boolean::class.javaPrimitiveType
                        )
                        method.isAccessible = true
                        method.invoke(this, true)
                    } catch (e: Exception) {
                        // 方法可能不存在于某些设备上
                    }
                }
                
                // 方法2: 尝试禁用 size compat mode
                try {
                    val wmClass = Class.forName("android.view.WindowManager\$LayoutParams")
                    val flagField = wmClass.getDeclaredField("PRIVATE_FLAG_FORCE_DECOR_VIEW_VISIBILITY")
                    flagField.isAccessible = true
                    val flagValue = flagField.getInt(null)
                    
                    val params = window.attributes
                    val privateFlags = params.javaClass.getDeclaredField("privateFlags")
                    privateFlags.isAccessible = true
                    privateFlags.setInt(params, privateFlags.getInt(params) or flagValue)
                    window.attributes = params
                } catch (e: Exception) {
                    // 忽略
                }
                
                // 方法3: 尝试通过 WindowManager 禁用方向锁定
                try {
                    val wm = getSystemService(WINDOW_SERVICE) as WindowManager
                    val wmClass = wm.javaClass
                    val methods = wmClass.declaredMethods
                    for (method in methods) {
                        if (method.name.contains("setIgnoreOrientationRequest", ignoreCase = true)) {
                            method.isAccessible = true
                            method.invoke(wm, true)
                            break
                        }
                    }
                } catch (e: Exception) {
                    // 忽略
                }
                
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    /**
     * 获取 letterbox 状态信息
     */
    private fun getLetterboxStatus(): Map<String, Any> {
        val decorView = window.decorView
        val contentView = decorView.findViewById<View>(android.R.id.content)
        
        val decorRect = Rect()
        val contentRect = Rect()
        decorView.getGlobalVisibleRect(decorRect)
        contentView?.getGlobalVisibleRect(contentRect)
        
        val dm = resources.displayMetrics
        
        return mapOf(
            "decorWidth" to decorRect.width(),
            "decorHeight" to decorRect.height(),
            "contentWidth" to contentRect.width(),
            "contentHeight" to contentRect.height(),
            "displayWidth" to dm.widthPixels,
            "displayHeight" to dm.heightPixels,
            "density" to dm.density,
            "hasLetterbox" to (decorRect.width() < dm.widthPixels || decorRect.height() < dm.heightPixels),
            "apiLevel" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL
        )
    }

    /**
     * 设置屏幕方向（供 Flutter 调用）
     * 这个方法会绕过系统的 letterbox 限制
     */
    private fun setScreenOrientation(orientation: String?) {
        // 先禁用 letterbox
        disableLetterboxing()
        
        val newOrientation = when (orientation) {
            "portrait" -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            "portraitUp" -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            "portraitDown" -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
            "portraitAuto" -> ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT
            "landscape" -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            "landscapeLeft" -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            "landscapeRight" -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
            "landscapeAuto" -> ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            "auto" -> ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR
            "unspecified" -> ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            "userPortrait" -> ActivityInfo.SCREEN_ORIENTATION_USER_PORTRAIT
            "userLandscape" -> ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE
            "user" -> ActivityInfo.SCREEN_ORIENTATION_USER
            "fullUser" -> ActivityInfo.SCREEN_ORIENTATION_FULL_USER
            "locked" -> ActivityInfo.SCREEN_ORIENTATION_LOCKED
            "behind" -> ActivityInfo.SCREEN_ORIENTATION_BEHIND
            "nosensor" -> ActivityInfo.SCREEN_ORIENTATION_NOSENSOR
            "sensor" -> ActivityInfo.SCREEN_ORIENTATION_SENSOR
            else -> ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        
        requestedOrientation = newOrientation
        
        // 强制全屏
        forceFullscreen()
    }

    /**
     * 获取屏幕信息
     */
    private fun getScreenInfo(): Map<String, Any> {
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }
        
        val rotation = display?.rotation ?: Surface.ROTATION_0
        val config = resources.configuration
        
        return mapOf(
            "rotation" to rotation,
            "orientation" to config.orientation,
            "isLandscape" to (config.orientation == Configuration.ORIENTATION_LANDSCAPE),
            "screenWidthDp" to config.screenWidthDp,
            "screenHeightDp" to config.screenHeightDp,
            "smallestScreenWidthDp" to config.smallestScreenWidthDp,
            "isTablet" to (config.smallestScreenWidthDp >= 600),
            "currentOrientation" to requestedOrientation,
            "apiLevel" to Build.VERSION.SDK_INT
        )
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (interceptVolumeEvent && (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)) {
            volumeMethodChannel.invokeMethod(
                "event",
                if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) 1 else -1
            )
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (interceptVolumeEvent && (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)) {
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    override fun onDestroy() {
        volumeMethodChannel.setMethodCallHandler(null)
        orientationMethodChannel.setMethodCallHandler(null)
        super.onDestroy()
    }
}
