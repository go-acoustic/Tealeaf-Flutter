package com.example.tl_flutter_plugin_example;

import android.view.MotionEvent;

import com.tl.uic.Tealeaf;

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    public boolean dispatchTouchEvent(MotionEvent e) {
        Tealeaf.dispatchTouchEvent(this, e);
        return super.dispatchTouchEvent(e);
    }
}
