package com.example.mp3trim

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SAVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveWav" -> {
                        if (pendingSaveResult != null) {
                            result.error("SAVE_ACTIVE", "A save request is already active.", null)
                            return@setMethodCallHandler
                        }

                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("SAVE_BYTES_EMPTY", "No audio bytes were provided.", null)
                            return@setMethodCallHandler
                        }

                        val fileName = ensureWavExtension(
                            call.argument<String>("fileName") ?: "concatenated.wav"
                        )
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "audio/wav"
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }

                        pendingSaveResult = result
                        pendingSaveBytes = bytes

                        try {
                            startActivityForResult(intent, SAVE_WAV_REQUEST_CODE)
                        } catch (error: Exception) {
                            clearPendingSave()
                            result.error("SAVE_PICKER_FAILED", error.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == SAVE_WAV_REQUEST_CODE) {
            val result = pendingSaveResult
            val bytes = pendingSaveBytes
            clearPendingSave()

            if (result == null) {
                return
            }
            if (resultCode != Activity.RESULT_OK) {
                result.success(null)
                return
            }

            val uri: Uri? = data?.data
            if (uri == null || bytes == null) {
                result.error("SAVE_URI_MISSING", "No destination was selected.", null)
                return
            }

            try {
                val savedUri = ensureSelectedWavExtension(uri)
                contentResolver.openOutputStream(savedUri, "wt").use { output ->
                    if (output == null) {
                        throw IllegalStateException("Could not open selected destination.")
                    }
                    output.write(bytes)
                    output.flush()
                }
                result.success(destinationFolderName(savedUri))
            } catch (error: Exception) {
                result.error("SAVE_WRITE_FAILED", error.message, null)
            }
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun ensureSelectedWavExtension(uri: Uri): Uri {
        val displayName = displayName(uri) ?: return uri
        if (displayName.endsWith(".wav", ignoreCase = true)) {
            return uri
        }

        return try {
            DocumentsContract.renameDocument(contentResolver, uri, "$displayName.wav") ?: uri
        } catch (_: Exception) {
            uri
        }
    }

    private fun displayName(uri: Uri): String? {
        return contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) {
                    return@use null
                }
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex < 0) null else cursor.getString(nameIndex)
            }
    }

    private fun destinationFolderName(uri: Uri): String {
        val documentId = try {
            DocumentsContract.getDocumentId(uri)
        } catch (_: Exception) {
            null
        }

        val folderName = documentId?.let { folderNameFromDocumentId(it) }
        if (!folderName.isNullOrBlank()) {
            return folderName
        }

        return "selected folder"
    }

    private fun folderNameFromDocumentId(documentId: String): String? {
        val pathPart = documentId.substringAfter(':', documentId)
        val parentPath = pathPart.substringBeforeLast('/', missingDelimiterValue = "")
        if (parentPath.isBlank()) {
            return null
        }
        return parentPath.substringAfterLast('/').ifBlank { null }
    }

    private fun clearPendingSave() {
        pendingSaveResult = null
        pendingSaveBytes = null
    }

    private fun ensureWavExtension(fileName: String): String {
        return if (fileName.endsWith(".wav", ignoreCase = true)) fileName else "$fileName.wav"
    }

    companion object {
        private const val SAVE_CHANNEL = "mp3trim/save_audio"
        private const val SAVE_WAV_REQUEST_CODE = 9307
    }
}
