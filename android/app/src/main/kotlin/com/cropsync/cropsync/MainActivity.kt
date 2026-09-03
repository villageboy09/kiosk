package com.cropsync.cropsync

import android.content.Context
import android.telephony.SubscriptionManager
import android.telephony.SubscriptionInfo
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "cropsync/sim_info"
    private val PERMISSION_REQUEST_CODE = 123
    private var pendingResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val params = window.attributes
            params.layoutInDisplayCutoutMode =
                android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            window.attributes = params
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSimInfo") {
                if (hasPhonePermission()) {
                    result.success(getSimDetails())
                } else {
                    pendingResult = result
                    requestPhonePermission()
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun hasPhonePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val statePermission = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
            val numbersPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_NUMBERS) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
            statePermission && numbersPermission
        } else {
            true
        }
    }

    private fun requestPhonePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                arrayOf(Manifest.permission.READ_PHONE_STATE, Manifest.permission.READ_PHONE_NUMBERS)
            } else {
                arrayOf(Manifest.permission.READ_PHONE_STATE)
            }
            ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val result = pendingResult
            pendingResult = null
            if (result != null) {
                result.success(getSimDetails())
            }
        }
    }

    private fun getSimDetails(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                if (subscriptionManager != null) {
                    val activeList = try {
                        subscriptionManager.activeSubscriptionInfoList
                    } catch (e: SecurityException) {
                        null
                    }
                    if (activeList != null) {
                        for (info in activeList) {
                            val map = mutableMapOf<String, Any>()
                            map["slot"] = info.simSlotIndex + 1
                            map["carrier"] = info.carrierName?.toString() ?: "Unknown Carrier"
                            val num = info.number ?: ""
                            map["number"] = if (num.isNotEmpty()) num else ""
                            list.add(map)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return list
    }
}
