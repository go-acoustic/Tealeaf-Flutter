package io.flutter.demo.gallery

import android.view.MotionEvent
import com.tl.uic.Tealeaf
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.lang.ref.WeakReference


class MainActivity : FlutterActivity() {

    override fun dispatchTouchEvent(e: MotionEvent?): Boolean {
        Tealeaf.dispatchTouchEvent(this, e)

        return super.dispatchTouchEvent(e)
    }
}