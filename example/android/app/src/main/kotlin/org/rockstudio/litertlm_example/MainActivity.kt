package org.rockstudio.litertlm_example

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
  private var pendingResult: MethodChannel.Result? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        MODEL_DIRECTORY_CHANNEL,
      )
      .setMethodCallHandler { call, result ->
        if (call.method != PICK_MODEL_DIRECTORY) {
          result.notImplemented()
          return@setMethodCallHandler
        }
        if (pendingResult != null) {
          result.error("picker_busy", "A model folder picker is already open.", null)
          return@setMethodCallHandler
        }

        pendingResult = result
        try {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            !Environment.isExternalStorageManager()
          ) {
            val intent =
              Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:$packageName"),
              )
            startActivityForResult(intent, ALL_FILES_ACCESS_REQUEST)
          } else {
            openDirectoryPicker()
          }
        } catch (error: Exception) {
          finishWithError("picker_failed", error.message ?: error.toString())
        }
      }
  }

  private fun openDirectoryPicker() {
    val intent =
      Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
        addFlags(
          Intent.FLAG_GRANT_READ_URI_PERMISSION or
            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
        )
      }
    startActivityForResult(intent, DIRECTORY_PICKER_REQUEST)
  }

  @Deprecated("Deprecated in Android; retained for FlutterActivity compatibility")
  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    when (requestCode) {
      ALL_FILES_ACCESS_REQUEST -> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
          Environment.isExternalStorageManager()
        ) {
          try {
            openDirectoryPicker()
          } catch (error: Exception) {
            finishWithError("picker_failed", error.message ?: error.toString())
          }
        } else {
          finishWithError(
            "all_files_access_denied",
            "Allow all-files access to load a model directly without copying it.",
          )
        }
      }

      DIRECTORY_PICKER_REQUEST -> {
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
          pendingResult?.success(null)
          pendingResult = null
          return
        }
        try {
          val uri = requireNotNull(data.data)
          contentResolver.takePersistableUriPermission(
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
          )
          pendingResult?.success(resolveExternalStoragePath(uri))
          pendingResult = null
        } catch (error: Exception) {
          finishWithError("unsupported_directory", error.message ?: error.toString())
        }
      }
    }
  }

  private fun resolveExternalStoragePath(uri: Uri): String {
    require(uri.authority == EXTERNAL_STORAGE_AUTHORITY) {
      "Select a folder in the device's local or SD-card storage."
    }
    val documentId = DocumentsContract.getTreeDocumentId(uri)
    val parts = documentId.split(':', limit = 2)
    val volume = parts[0]
    val relativePath = parts.getOrElse(1) { "" }
    val root =
      if (volume.equals("primary", ignoreCase = true)) {
        Environment.getExternalStorageDirectory()
      } else {
        File("/storage", volume)
      }
    val canonicalRoot = root.canonicalFile
    val selected = File(canonicalRoot, relativePath).canonicalFile
    require(selected == canonicalRoot || selected.path.startsWith("${canonicalRoot.path}${File.separator}")) {
      "The selected folder is outside the storage volume."
    }
    require(selected.isDirectory && selected.canRead()) {
      "The selected folder cannot be read directly: ${selected.path}"
    }
    return selected.path
  }

  private fun finishWithError(code: String, message: String) {
    pendingResult?.error(code, message, null)
    pendingResult = null
  }

  private companion object {
    const val MODEL_DIRECTORY_CHANNEL =
      "org.rockstudio.litertlm_example/model_directory"
    const val PICK_MODEL_DIRECTORY = "pickModelDirectory"
    const val EXTERNAL_STORAGE_AUTHORITY =
      "com.android.externalstorage.documents"
    const val ALL_FILES_ACCESS_REQUEST = 4101
    const val DIRECTORY_PICKER_REQUEST = 4102
  }
}
