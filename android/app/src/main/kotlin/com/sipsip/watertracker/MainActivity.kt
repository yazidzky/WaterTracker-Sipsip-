package com.sipsip.watertracker

import io.flutter.embedding.android.FlutterActivity

import androidx.core.view.WindowCompat
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}
