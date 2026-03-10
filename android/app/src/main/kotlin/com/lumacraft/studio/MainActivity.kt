package com.lumacraft.studio

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import android.media.MediaMetadataRetriever

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.lumacraft.studio/video_picker"
    private val PICK_VIDEO_REQUEST = 9001

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickVideo" -> {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "video/*"
                    }
                    startActivityForResult(intent, PICK_VIDEO_REQUEST)
                }
                "getCachePath" -> {
                    result.success(cacheDir.absolutePath)
                }
                "getMediaDuration" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            val retriever = MediaMetadataRetriever()
                            try {
                                retriever.setDataSource(path)
                            } catch (e: Exception) {
                                val fd = java.io.FileInputStream(path).fd
                                retriever.setDataSource(fd)
                            }
                            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                            retriever.release()
                            result.success(durationStr)
                        } catch (e: Exception) {
                            result.error("METADATA_ERROR", "Failed to extract duration: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Path cannot be null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_VIDEO_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri: Uri = data.data!!
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                } catch (_: SecurityException) {
                    // Some providers don't support persistable permissions
                }

                try {
                    val ext = getFileExtension(uri) ?: "mp4"
                    val cacheFile = File(cacheDir, "picked_${UUID.randomUUID()}.$ext")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(cacheFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    pendingResult?.success(cacheFile.absolutePath)
                } catch (e: Exception) {
                    pendingResult?.error("COPY_ERROR", "Failed to copy video: ${e.message}", null)
                }
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }

    private fun getFileExtension(uri: Uri): String? {
        val mimeType = contentResolver.getType(uri) ?: return null
        return when {
            mimeType.contains("mp4") -> "mp4"
            mimeType.contains("3gp") -> "3gp"
            mimeType.contains("webm") -> "webm"
            mimeType.contains("mkv") -> "mkv"
            mimeType.contains("avi") -> "avi"
            else -> "mp4"
        }
    }
}
