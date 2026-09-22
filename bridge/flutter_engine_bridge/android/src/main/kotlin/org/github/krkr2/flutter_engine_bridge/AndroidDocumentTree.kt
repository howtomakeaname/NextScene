package org.github.krkr2.flutter_engine_bridge

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.DocumentsContract as DC
import android.system.OsConstants
import java.io.File
import java.io.FileNotFoundException
import java.util.concurrent.ConcurrentHashMap

/** One persisted, user-selected Downloads tree. Native readers borrow owned file descriptors. */
object AndroidDocumentTree {
    private lateinit var context: Context
    private val ids = ConcurrentHashMap<String, String>()
    private val projection = arrayOf(DC.Document.COLUMN_DOCUMENT_ID, DC.Document.COLUMN_DISPLAY_NAME,
        DC.Document.COLUMN_MIME_TYPE, DC.Document.COLUMN_SIZE, DC.Document.COLUMN_LAST_MODIFIED)
    private const val AUTHORITY = "com.android.externalstorage.documents"
    private const val PREFS = "nextscene_document_tree"
    private const val KEY = "tree"

    fun initialize(value: Context) { context = value.applicationContext }
    val rootPath: String get() = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), context.packageName).path
    private val rootId: String get() = "primary:Download/${context.packageName}"
    val initialUri: Uri get() = DC.buildDocumentUri(AUTHORITY, rootId)

    class Failure(val code: String) : Exception(code)
    data class Doc(val id: String, val name: String, val directory: Boolean, val size: Long, val modified: Long) {
        fun map(path: String): Map<String, Any> = mapOf("path" to path, "directory" to directory,
            "size" to size, "modified" to modified)
    }

    fun accepts(uri: Uri): Boolean = uri.scheme == "content" && uri.authority == AUTHORITY &&
        DC.isTreeUri(uri) && DC.getTreeDocumentId(uri) == rootId

    fun saveGrant(uri: Uri, flags: Int) {
        if (!accepts(uri)) throw Failure("outside_root")
        val needed = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        if (flags and needed != needed) throw Failure("permission_denied")
        context.contentResolver.takePersistableUriPermission(uri, needed)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, uri.toString()).commit()
        ids.clear()
    }

    fun hasGrant(): Boolean = treeOrNull() != null
    private fun treeOrNull(): Uri? {
        val value = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return null
        val uri = Uri.parse(value)
        if (!accepts(uri)) return null
        return if (context.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }) uri else null
    }
    private fun tree(): Uri = treeOrNull() ?: throw Failure("permission_denied")
    private fun uri(id: String): Uri {
        if (id != rootId && !id.startsWith("$rootId/")) throw Failure("outside_root")
        return DC.buildDocumentUriUsingTree(tree(), id)
    }
    private fun relative(path: String): String {
        val normalized = File(path).normalize().path.trimEnd('/')
        val root = rootPath
        if (normalized.equals(root, true)) return ""
        if (!normalized.startsWith("$root/", true)) throw Failure("outside_root")
        return normalized.substring(root.length + 1)
    }
    @JvmStatic fun ownsPath(path: String): Boolean = try { relative(path); true } catch (_: Failure) { false }

    private fun query(documentUri: Uri): List<Doc> {
        val result = ArrayList<Doc>()
        val cursor = context.contentResolver.query(documentUri, projection, null, null, null)
            ?: throw Failure("permission_denied")
        cursor.use {
            while (it.moveToNext()) {
                val id = it.getString(0)
                if (id != rootId && !id.startsWith("$rootId/")) throw Failure("outside_root")
                val name = it.getString(1)
                if (name == "." || name == ".." || name.contains('/') || name.contains('\\')) throw Failure("unsupported_link")
                result.add(Doc(id, name, it.getString(2) == DC.Document.MIME_TYPE_DIR,
                    if (it.isNull(3)) 0 else it.getLong(3), if (it.isNull(4)) 0 else it.getLong(4)))
            }
        }
        return result
    }
    private fun children(id: String): List<Doc> = query(DC.buildChildDocumentsUriUsingTree(tree(), id))
    private fun find(path: String): Doc? {
        val rel = relative(path)
        val cached = ids[rel]
        if (cached != null) {
            val value = try { query(uri(cached)).firstOrNull() } catch (_: FileNotFoundException) { null }
            if (value != null) return value
            ids.remove(rel)
        }
        var value = query(uri(rootId)).firstOrNull() ?: throw Failure("not_found")
        var prefix = ""
        for (name in rel.split('/').filter { it.isNotEmpty() }) {
            if (!value.directory) return null
            val entries = children(value.id)
            value = entries.firstOrNull { it.name == name }
                ?: entries.singleOrNull { it.name.equals(name, true) } ?: return null
            prefix = if (prefix.isEmpty()) name else "$prefix/$name"
            ids[prefix] = value.id
        }
        return value
    }
    fun stat(path: String): Map<String, Any>? = find(path)?.map(path)
    fun list(path: String): List<Map<String, Any>> {
        val parent = find(path) ?: throw Failure("not_found")
        if (!parent.directory) throw Failure("not_found")
        return children(parent.id).map {
            val child = "${path.trimEnd('/')}/${it.name}"
            ids[relative(child)] = it.id
            it.map(child)
        }
    }
    fun documentUri(path: String): String = uri((find(path) ?: throw Failure("not_found")).id).toString()
    private fun vacant(path: String) {
        if (find(path) != null) throw Failure("conflict")
    }
    fun mkdir(path: String, recursive: Boolean) {
        val existing = find(path)
        if (existing != null) {
            if (!existing.directory) throw Failure("conflict")
            return
        }
        val parentPath = File(path).parent ?: throw Failure("outside_root")
        if (recursive) mkdir(parentPath, true)
        val parent = find(parentPath) ?: throw Failure("not_found")
        val result = DC.createDocument(context.contentResolver, uri(parent.id), DC.Document.MIME_TYPE_DIR, File(path).name)
            ?: throw Failure("failed")
        val created = query(result).single()
        if (created.name != File(path).name) {
            DC.deleteDocument(context.contentResolver, result)
            throw Failure("conflict")
        }
        ids.clear()
    }
    fun rename(from: String, to: String) {
        val fromRel = relative(from); val toRel = relative(to)
        if (fromRel.isEmpty() || toRel.isEmpty()) throw Failure("protected_directory")
        if (toRel == fromRel || toRel.startsWith("$fromRel/")) throw Failure("recursive_target")
        vacant(to)
        val source = find(from) ?: throw Failure("not_found")
        val oldParent = find(File(from).parent!!) ?: throw Failure("not_found")
        val newParent = find(File(to).parent!!) ?: throw Failure("not_found")
        var current = uri(source.id)
        var moved = false
        try {
            if (oldParent.id != newParent.id) {
                // A task payload is normally called "item". Give it a unique
                // temporary name before moving so an unrelated item in the
                // destination cannot force provider auto-renaming.
                val temporary = ".nextscene-move-${java.util.UUID.randomUUID()}"
                current = DC.renameDocument(context.contentResolver, current, temporary) ?: throw Failure("failed")
                current = DC.moveDocument(context.contentResolver, current, uri(oldParent.id), uri(newParent.id))
                    ?: throw Failure("failed")
                moved = true
            }
            if (query(current).single().name != File(to).name) {
                current = DC.renameDocument(context.contentResolver, current, File(to).name) ?: throw Failure("failed")
            }
            if (query(current).single().name != File(to).name) throw Failure("conflict")
        } catch (e: Exception) {
            // Roll back both parent and name; preserve the original failure if
            // a revoked grant prevents rollback too.
            try {
                if (moved) current = DC.moveDocument(context.contentResolver, current, uri(newParent.id), uri(oldParent.id)) ?: current
                if (query(current).firstOrNull()?.name != source.name) {
                    DC.renameDocument(context.contentResolver, current, source.name)
                }
            } catch (rollback: Exception) { e.addSuppressed(rollback) }
            throw e
        } finally { ids.clear() }
    }

    fun delete(path: String, recursive: Boolean) {
        if (relative(path).isEmpty()) throw Failure("protected_directory")
        val doc = find(path) ?: return
        if (doc.directory && !recursive && children(doc.id).isNotEmpty()) throw Failure("conflict")
        if (!DC.deleteDocument(context.contentResolver, uri(doc.id))) throw Failure("failed")
        ids.clear()
    }
    fun open(path: String, mode: String): Int {
        if (mode !in setOf("r", "rw", "rwt", "wa")) throw Failure("failed")
        relative(path)
        var doc = find(path)
        if (doc == null && mode != "r") {
            val parent = find(File(path).parent!!) ?: throw Failure("not_found")
            val created = DC.createDocument(context.contentResolver, uri(parent.id), "application/octet-stream", File(path).name)
                ?: throw Failure("failed")
            doc = query(created).single()
            if (doc.name != File(path).name) {
                DC.deleteDocument(context.contentResolver, created)
                throw Failure("conflict")
            }
            ids.clear()
        }
        if (doc == null) throw Failure("not_found")
        if (doc.directory) throw Failure("unsupported_link")
        return context.contentResolver.openFileDescriptor(uri(doc.id), mode)?.detachFd() ?: throw Failure("failed")
    }
    fun ensureRoot(): Map<String, String> {
        if (find(rootPath) == null) throw Failure("not_found")
        mkdir("$rootPath/games", true)
        return mapOf("root" to rootPath, "games" to "$rootPath/games",
            "display" to "Download/${context.packageName}", "appId" to context.packageName)
    }
    @JvmStatic fun nativeMkdir(path: String): Boolean = try { mkdir(path, true); true } catch (_: Exception) { false }
    @JvmStatic fun nativeDelete(path: String): Boolean = try { delete(path, false); true } catch (_: Exception) { false }
    @JvmStatic fun nativeRename(from: String, to: String): Boolean = try { rename(from, to); true } catch (_: Exception) { false }
    @JvmStatic fun nativeOpen(path: String, flags: Int): Int = try {
        if (flags and OsConstants.O_CREAT == 0 && find(path) == null) -OsConstants.ENOENT
        else open(path, when {
            flags and OsConstants.O_TRUNC != 0 -> "rwt"
            flags and OsConstants.O_APPEND != 0 -> "wa"
            flags and (OsConstants.O_WRONLY or OsConstants.O_RDWR) != 0 -> "rw"
            else -> "r"
        })
    } catch (e: Exception) { if (e is Failure && e.code == "not_found" || e is FileNotFoundException) -OsConstants.ENOENT else -OsConstants.EACCES }
    @JvmStatic fun nativeStat(path: String): LongArray? = try {
        find(path)?.let { longArrayOf(if (it.directory) 2 else 1, it.size, it.modified / 1000) }
    } catch (_: Exception) { null }
    @JvmStatic fun nativeList(path: String): Array<String>? = try {
        list(path).map { File(it["path"] as String).name }.toTypedArray()
    } catch (_: Exception) { null }
}
