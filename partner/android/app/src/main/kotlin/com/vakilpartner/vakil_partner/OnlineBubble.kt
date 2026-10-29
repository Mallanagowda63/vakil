package com.vakilpartner.vakil_partner

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import kotlin.math.abs

/**
 * The Rapido/Uber-style bubble: while the lawyer is online and has left the
 * app, a round Legally Talk logo floats over other apps. It can be dragged,
 * snaps to the nearest left or right edge, and a tap brings the app back.
 * Shown and hidden from Dart (lib/services/online_bubble.dart); needs the
 * "Display over other apps" permission. Lives as long as the app's process.
 */
object OnlineBubble {
    private var view: View? = null
    private var params: WindowManager.LayoutParams? = null
    // Where the lawyer left it last time (edge and height), for this run of the app.
    private var lastX: Int? = null
    private var lastY: Int? = null

    fun canDraw(context: Context) = Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    fun openPermissionSettings(context: Context) {
        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    @SuppressLint("ClickableViewAccessibility")
    fun show(context: Context): Boolean {
        val app = context.applicationContext
        if (view != null) return true
        if (!canDraw(app)) return false
        val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val density = app.resources.displayMetrics.density
        val size = (58 * density).toInt()
        val screenW = app.resources.displayMetrics.widthPixels
        val screenH = app.resources.displayMetrics.heightPixels

        val bubble = FrameLayout(app).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
                setStroke((2.5f * density).toInt(), Color.parseColor("#2454E0"))
            }
            elevation = 8 * density
        }
        bubble.addView(ImageView(app).apply {
            setImageResource(R.mipmap.ic_launcher_foreground)
            scaleType = ImageView.ScaleType.CENTER_CROP
        }, FrameLayout.LayoutParams(size, size))
        // Green "online" dot.
        val dot = (14 * density).toInt()
        bubble.addView(View(app).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#19A968"))
                setStroke((2 * density).toInt(), Color.WHITE)
            }
        }, FrameLayout.LayoutParams(dot, dot, Gravity.TOP or Gravity.END))

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
        val lp = WindowManager.LayoutParams(size, size, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP or Gravity.START
            x = lastX ?: (screenW - size)
            y = lastY ?: (screenH * 0.35).toInt()
        }

        var downX = 0f; var downY = 0f; var startX = 0; var startY = 0; var moved = false
        bubble.setOnTouchListener { v, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY; startX = lp.x; startY = lp.y; moved = false
                    v.animate().scaleX(0.92f).scaleY(0.92f).setDuration(80).start()
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX; val dy = e.rawY - downY
                    if (abs(dx) > 10 * density || abs(dy) > 10 * density) moved = true
                    if (moved) {
                        lp.x = (startX + dx).toInt().coerceIn(0, screenW - size)
                        lp.y = (startY + dy).toInt().coerceIn(0, screenH - size)
                        runCatching { wm.updateViewLayout(v, lp) }
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    v.animate().scaleX(1f).scaleY(1f).setDuration(80).start()
                    if (!moved && e.action == MotionEvent.ACTION_UP) openApp(app)
                    else snapToEdge(wm, v, lp, screenW, size)
                }
            }
            true
        }

        return runCatching { wm.addView(bubble, lp); view = bubble; params = lp; true }.getOrDefault(false)
    }

    /** Slides to whichever side (left or right) is closer, like ride-hailing apps. */
    private fun snapToEdge(wm: WindowManager, v: View, lp: WindowManager.LayoutParams, screenW: Int, size: Int) {
        val target = if (lp.x + size / 2 < screenW / 2) 0 else screenW - size
        ValueAnimator.ofInt(lp.x, target).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
            addUpdateListener { lp.x = it.animatedValue as Int; runCatching { wm.updateViewLayout(v, lp) } }
            start()
        }
        lastX = target; lastY = lp.y
    }

    private fun openApp(context: Context) {
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        runCatching { context.startActivity(intent) }
        hide(context)
    }

    fun hide(context: Context) {
        val v = view ?: return
        params?.let { lastX = it.x; lastY = it.y }
        val wm = context.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        runCatching { wm.removeView(v) }
        view = null; params = null
    }
}
