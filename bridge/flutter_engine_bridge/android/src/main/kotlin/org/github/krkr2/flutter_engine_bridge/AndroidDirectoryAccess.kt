package org.github.krkr2.flutter_engine_bridge

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.io.FileNotFoundException
import java.util.concurrent.Executors

/** The picker grants only Download/<applicationId>; all I/O stays on that tree. */
internal class AndroidDirectoryAccess(context: Context) {
    private var pendingResult: Result? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    init { AndroidDocumentTree.initialize(context) }

    companion object { private const val TREE_REQUEST = 9002 }

    private fun run(result: Result, recover: (() -> Unit)? = null, operation: () -> Any?) {
        worker.execute {
            try {
                val value = operation()
                main.post { result.success(value) }
            } catch (error: Exception) {
                val code = when (error) {
                    is AndroidDocumentTree.Failure -> error.code
                    is SecurityException -> "permission_denied"
                    is FileNotFoundException -> "not_found"
                    else -> "failed"
                }
                main.post {
                    if (recover != null && code in setOf("permission_denied", "not_found")) recover()
                    else result.error(code, "Directory operation failed", null)
                }
            }
        }
    }

    fun handle(call: MethodCall, result: Result, activity: Activity?): Boolean {
        val tree = AndroidDocumentTree
        when (call.method) {
            "ensureManagerRoot" -> {
                if (tree.hasGrant()) run(result, recover = if (call.argument<Boolean>("prompt") == true) ({ request(result, activity) }) else null) { tree.ensureRoot() }
                else if (call.argument<Boolean>("prompt") == true) request(result, activity)
                else result.success(null)
            }
            "ensurePublicGamesDir" -> run(result) {
                if (!tree.hasGrant()) null else tree.ensureRoot().let {
                    mapOf("path" to it["games"], "display" to "${it["display"]}/games")
                }
            }
            "documentStat" -> run(result) { tree.stat(call.argument<String>("path")!!) }
            "documentList" -> run(result) { tree.list(call.argument<String>("path")!!) }
            "documentUri" -> run(result) { tree.documentUri(call.argument<String>("path")!!) }
            "documentOpen" -> run(result) { tree.open(call.argument<String>("path")!!, call.argument<String>("mode")!!) }
            "documentMkdir" -> run(result) { tree.mkdir(call.argument<String>("path")!!, call.argument<Boolean>("recursive") == true); null }
            "documentDelete" -> run(result) { tree.delete(call.argument<String>("path")!!, call.argument<Boolean>("recursive") == true); null }
            "documentRename" -> run(result) { tree.rename(call.argument<String>("from")!!, call.argument<String>("to")!!); null }
            else -> return false
        }
        return true
    }

    private fun request(result: Result, activity: Activity?) {
        if (pendingResult != null) { result.error("busy", "Directory picker is already open", null); return }
        if (activity == null) { result.error("permission_denied", "No activity for directory picker", null); return }
        pendingResult = result
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, AndroidDocumentTree.initialUri)
            }, TREE_REQUEST)
        } catch (_: Exception) {
            pendingResult = null
            result.error("permission_denied", "Unable to open directory picker", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != TREE_REQUEST) return false
        val result = pendingResult ?: return true
        pendingResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.error("cancelled", "Directory picker cancelled", null)
        } else run(result) {
            AndroidDocumentTree.saveGrant(uri, data.flags)
            AndroidDocumentTree.ensureRoot()
        }
        return true
    }

    fun detach() {
        pendingResult?.error("cancelled", "Directory picker interrupted", null)
        pendingResult = null
    }
}
