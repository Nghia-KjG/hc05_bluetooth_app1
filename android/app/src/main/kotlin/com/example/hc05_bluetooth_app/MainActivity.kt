package com.example.hc05_bluetooth_app

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.hc.bluetoothlibrary.AllBluetoothManage
import com.hc.bluetoothlibrary.DeviceModule
import com.hc.bluetoothlibrary.IBluetooth
import android.media.ToneGenerator
import android.media.AudioManager
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import android.content.pm.PackageInstaller
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.os.Build
import java.io.FileInputStream

class MainActivity: FlutterActivity(), IBluetooth {
    private val METHOD_CHANNEL = "com.hc.bluetooth.method_channel"
    private val EVENT_CHANNEL = "com.hc.bluetooth.event_channel"
    private val AUDIO_CHANNEL = "com.hc.audio.channel"
    private val INSTALL_CHANNEL = "com.hc.install.channel"

    private lateinit var bluetoothManage: AllBluetoothManage
    private var eventSink: EventChannel.EventSink? = null
    private val scannedDevices = mutableMapOf<String, DeviceModule>()
    
    companion object {
        private const val INSTALL_ACTION = "com.example.hc05_bluetooth_app.INSTALL_ACTION"
    }
    
    private val installReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (val status = intent?.getIntExtra(PackageInstaller.EXTRA_STATUS, -1)) {
                PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                    // User needs to confirm - launch the confirm intent
                    val confirmIntent = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                    confirmIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        startActivity(confirmIntent)
                        android.util.Log.i("InstallDebug", "❓ Yêu cầu user xác nhận")
                    } catch (e: Exception) {
                        android.util.Log.e("InstallDebug", "❌ Lỗi mở confirm intent: ${e.message}")
                    }
                }
                PackageInstaller.STATUS_SUCCESS -> {
                    android.util.Log.i("InstallDebug", "✅ Cài đặt thành công!")
                    // Restart app after 1 second
                    restartApp()
                }
                PackageInstaller.STATUS_FAILURE,
                PackageInstaller.STATUS_FAILURE_ABORTED,
                PackageInstaller.STATUS_FAILURE_BLOCKED,
                PackageInstaller.STATUS_FAILURE_CONFLICT,
                PackageInstaller.STATUS_FAILURE_INCOMPATIBLE,
                PackageInstaller.STATUS_FAILURE_INVALID,
                PackageInstaller.STATUS_FAILURE_STORAGE -> {
                    val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                    android.util.Log.e("InstallDebug", "❌ Cài đặt thất bại: $message (status=$status)")
                }
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register install receiver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(installReceiver, IntentFilter(INSTALL_ACTION), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(installReceiver, IntentFilter(INSTALL_ACTION))
        }
        
        bluetoothManage = AllBluetoothManage(this, this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            val device = scannedDevices[call.argument<String>("address")]
            when (call.method) {
                "startScan" -> {
                    scannedDevices.clear()
                    bluetoothManage.mixScan()
                    result.success("Đã bắt đầu quét hỗn hợp")
                }
                "stopScan" -> {
                    bluetoothManage.stopScan()
                    result.success("Đã dừng quét")
                }
                "connect" -> {
                    if (device != null) {
                        bluetoothManage.connect(device)
                        result.success("Đang yêu cầu kết nối...")
                    } else {
                        result.error("NOT_FOUND", "Thiết bị không có trong danh sách đã quét.", null)
                    }
                }
                "disconnect" -> {
                    if (device != null) {
                        bluetoothManage.disconnect(device)
                        result.success("Đã ngắt kết nối")
                    } else {
                        result.error("NOT_FOUND", "Thiết bị không tồn tại", null)
                    }
                }
                "sendData" -> {
                    val data = call.argument<ByteArray>("data")
                    if (device != null && data != null) {
                        val dataString = String(data, Charsets.UTF_8).trim()
                        android.util.Log.i("BluetoothDebug", "📤 GỬI: $dataString (${data.size} bytes)")
                        bluetoothManage.sendData(device, data)
                        result.success("Đã gửi dữ liệu")
                    } else {
                        result.error("ERROR", "Thiết bị hoặc dữ liệu không hợp lệ.", null)
                    }
                }
                "setVelocity" -> {
                    val level = call.argument<Int>("level")
                    if (level != null) {
                        try {
                            // Dùng Reflection để truy cập ModuleParameters
                            val moduleParamsClass = Class.forName("com.hc.bluetoothlibrary.tootl.ModuleParameters")
                            val setLevelMethod = moduleParamsClass.getMethod("setLevel", Int::class.javaPrimitiveType)
                            setLevelMethod.invoke(null, level)
                            
                            android.util.Log.i("BluetoothDebug", "⚙️ Đặt level: $level (delay = ${level * 10}ms)")
                            result.success("Đã đặt tốc độ thành công (delay = ${level * 10}ms)")
                        } catch (e: Exception) {
                            android.util.Log.e("BluetoothDebug", "❌ Lỗi setLevel: ${e.message}")
                            e.printStackTrace()
                            result.error("ERROR", "Lỗi khi đặt tốc độ: ${e.message}", null)
                        }
                    } else {
                        result.error("ERROR", "Level không hợp lệ", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Audio Channel để phát âm thanh
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playTone" -> {
                    try {
                        val duration = call.argument<Int>("duration") ?: 200
                        playBeepSound(duration)
                        result.success("Âm thanh đã phát")
                    } catch (e: Exception) {
                        result.error("ERROR", "Lỗi phát âm thanh: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Install Channel để cài đặt APK
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    try {
                        val apkPath = call.argument<String>("apkPath")
                        if (apkPath != null) {
                            installApk(apkPath)
                            result.success("Đã mở trình cài đặt")
                        } else {
                            result.error("ERROR", "Đường dẫn APK không hợp lệ", null)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("InstallDebug", "❌ Lỗi cài đặt: ${e.message}")
                        result.error("ERROR", "Lỗi cài đặt: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }
    
    /// Phát tiếng bíp sử dụng ToneGenerator
    private fun playBeepSound(durationMs: Int) {
        try {
            val toneGenerator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
            toneGenerator.startTone(ToneGenerator.TONE_CDMA_CONFIRM, durationMs)
            android.util.Log.i("AudioDebug", "🔊 Phát Tone CONFIRM ($durationMs ms)")
        } catch (e: Exception) {
            android.util.Log.e("AudioDebug", "❌ Lỗi ToneGenerator: ${e.message}")
        }
    }
    
    /// Cài đặt APK sử dụng PackageInstaller API
    private fun installApk(apkPath: String) {
        try {
            val apkFile = File(apkPath)
            if (!apkFile.exists()) {
                android.util.Log.e("InstallDebug", "❌ File không tồn tại: $apkPath")
                return
            }
            
            android.util.Log.i("InstallDebug", "📦 Bắt đầu cài đặt qua PackageInstaller: $apkPath")
            
            val packageInstaller = packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            
            // Create session
            val sessionId = packageInstaller.createSession(params)
            val session = packageInstaller.openSession(sessionId)
            
            // Write APK to session
            FileInputStream(apkFile).use { input ->
                session.openWrite("package", 0, apkFile.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }
            
            // Create PendingIntent for install result
            val intent = Intent(INSTALL_ACTION)
            intent.setPackage(packageName)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                sessionId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            
            // Commit session
            session.commit(pendingIntent.intentSender)
            session.close()
            
            android.util.Log.i("InstallDebug", "✅ Session committed, chờ user xác nhận...")
        } catch (e: Exception) {
            android.util.Log.e("InstallDebug", "❌ Lỗi: ${e.message}")
            e.printStackTrace()
        }
    }
    
    /// Restart app sau khi cài đặt thành công
    private fun restartApp() {
        try {
            android.util.Log.i("InstallDebug", "🔄 Đang restart app...")
            
            // Đóng app hiện tại và mở lại sau 1.5 giây
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            alarmManager.setExact(
                android.app.AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 1500,
                pendingIntent
            )
            
            // Exit app
            finishAffinity()
            System.exit(0)
        } catch (e: Exception) {
            android.util.Log.e("InstallDebug", "❌ Lỗi restart: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(installReceiver)
        } catch (e: Exception) {
            // Ignore if already unregistered
        }
    }
    
    private fun sendEvent(event: Map<String, Any?>) { runOnUiThread { eventSink?.success(event) } }
    override fun updateList(device: DeviceModule?) {
        if (device != null) {
            scannedDevices[device.mac] = device
            android.util.Log.d("BluetoothDebug", "📡 Tìm thấy thiết bị: ${device.name} (${device.mac})")
            sendEvent(mapOf("type" to "scanResult", "name" to device.name, "address" to device.mac, "rssi" to device.rssi.toString()))
        }
    }
    override fun connectSucceed(module: DeviceModule?) {
        android.util.Log.d("BluetoothDebug", "✅ Kết nối thành công: ${module?.name} (${module?.mac})")
        sendEvent(mapOf("type" to "status", "status" to "connected", "message" to "Kết nối thành công tới ${module?.name}", "address" to module?.mac))
    }
    override fun errorDisconnect(device: DeviceModule?) {
        android.util.Log.e("BluetoothDebug", "❌ Mất kết nối: ${device?.name} (${device?.mac})")
        if (device != null) { bluetoothManage.disconnect(device) }
        sendEvent(mapOf("type" to "status", "status" to "disconnected", "message" to "Đã mất kết nối với ${device?.name ?: "thiết bị"}", "address" to device?.mac))
    }
    override fun readData(mac: String?, data: ByteArray?) {
        if (data != null) {
            val dataString = String(data, Charsets.UTF_8).trim()
            //android.util.Log.i("BluetoothDebug", "📥 NHẬN: $dataString (${data.size} bytes)")
            sendEvent(mapOf("type" to "dataReceived", "data" to data))
        }
    }
    override fun updateEnd() { sendEvent(mapOf("type" to "status", "status" to "scanFinished", "message" to "Quét hoàn tất")) }
    override fun updateMessyCode(p0: DeviceModule?) {}
    override fun reading(p0: Boolean) {}
    override fun readNumber(p0: Int) {}
    override fun readLog(p0: String?, p1: String?, p2: String?) {}
    override fun readVelocity(p0: Int) {}
    override fun callbackMTU(p0: Int) {}
}