package com.pivotapp.coach

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Bloqueo de capturas de pantalla (ficha de emergencia, 2026-11-07):
    // FLAG_SECURE impide capturas, grabaciones y la vista previa en Recientes.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pivot/seguridad").setMethodCallHandler { call, result ->
            when (call.method) {
                "bloquearCapturas" -> { window.addFlags(WindowManager.LayoutParams.FLAG_SECURE); result.success(null) }
                                "permitirCapturas" -> { window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE); result.success(null) }
                // Notificaciones bloqueadas (2026-11-18): abre los ajustes de notificaciones de Pivot.
                "abrirAjustesAvisos" -> {
                    try {
                        val i = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        else
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                        startActivity(i)
                    } catch (e: Exception) {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
