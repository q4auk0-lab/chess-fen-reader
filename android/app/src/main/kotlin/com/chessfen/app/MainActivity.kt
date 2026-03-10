// android/app/src/main/kotlin/com/chessfen/app/MainActivity.kt
package com.chessfen.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.chessfen.app/screen_capture"
    private val REQUEST_CODE = 1001

    private var projectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var pendingResult: MethodChannel.Result? = null

    private var screenWidth = 0
    private var screenHeight = 0
    private var screenDensity = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = wm.currentWindowMetrics.bounds
            screenWidth = bounds.width()
            screenHeight = bounds.height()
        } else {
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getMetrics(metrics)
            screenWidth = metrics.widthPixels
            screenHeight = metrics.heightPixels
        }
        screenDensity = resources.displayMetrics.densityDpi

        projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        pendingResult = result
                        val intent = projectionManager!!.createScreenCaptureIntent()
                        startActivityForResult(intent, REQUEST_CODE)
                    }
                    "captureScreen" -> {
                        if (mediaProjection == null) {
                            result.error("NO_PERMISSION", "MediaProjection izni yok", null)
                        } else {
                            captureScreen(result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                mediaProjection = projectionManager!!.getMediaProjection(resultCode, data)
                setupVirtualDisplay()
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }

    private fun setupVirtualDisplay() {
        imageReader = ImageReader.newInstance(
            screenWidth, screenHeight,
            PixelFormat.RGBA_8888, 2
        )

        virtualDisplay = mediaProjection!!.createVirtualDisplay(
            "ChessFenCapture",
            screenWidth, screenHeight, screenDensity,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader!!.surface, null, null
        )
    }

    private fun captureScreen(result: MethodChannel.Result) {
        val image: Image? = imageReader?.acquireLatestImage()
        if (image == null) {
            result.error("CAPTURE_FAILED", "Görüntü alınamadı", null)
            return
        }

        try {
            val planes = image.planes
            val buffer: ByteBuffer = planes[0].buffer
            val pixelStride = planes[0].pixelStride
            val rowStride = planes[0].rowStride
            val rowPadding = rowStride - pixelStride * screenWidth

            val bitmap = Bitmap.createBitmap(
                screenWidth + rowPadding / pixelStride,
                screenHeight,
                Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)

            // Tam ekran boyutuna kırp
            val croppedBitmap = Bitmap.createBitmap(bitmap, 0, 0, screenWidth, screenHeight)

            val outputStream = ByteArrayOutputStream()
            croppedBitmap.compress(Bitmap.CompressFormat.PNG, 90, outputStream)

            result.success(outputStream.toByteArray())

            bitmap.recycle()
            croppedBitmap.recycle()
        } catch (e: Exception) {
            result.error("CAPTURE_ERROR", e.message, null)
        } finally {
            image.close()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        virtualDisplay?.release()
        mediaProjection?.stop()
        imageReader?.close()
    }
}
