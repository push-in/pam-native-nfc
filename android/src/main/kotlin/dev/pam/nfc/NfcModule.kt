package dev.pam.nfc

import android.app.Activity
import android.content.Context
import android.nfc.*
import android.nfc.tech.Ndef
import android.util.Base64
import dev.pam.nativeapp.modules.*
import dev.pam.nativeapp.protocol.*
import org.json.JSONArray
import org.json.JSONObject

class NfcModule(context: Context) : NativeModule, NfcAdapter.ReaderCallback {
    private val activity = context as? Activity
    private val adapter = NfcAdapter.getDefaultAdapter(context)
    private val events = ArrayDeque<JSONObject>()
    @Volatile private var pending: NdefMessage? = null

    override fun invoke(method: String, payload: ByteArray, completion: ModuleCompletion) {
        val v = runCatching { WireMap.decode(payload) }.getOrElse { completion.fail(it); return }
        runCatching { when (method) {
            "availability" -> mapOf("availability" to WireValue.Integer(when { adapter == null -> 2; !adapter.isEnabled -> 3; else -> 1 }))
            "beginRead" -> { pending = null; begin(); emptyMap() }
            "write" -> { pending = message(v.text("recordsJson")); begin(); emptyMap() }
            "cancel" -> { cancel(); emptyMap() }
            "poll" -> mapOf("json" to WireValue.Text(poll(v.integer("limit").toInt()).toString()))
            else -> error("Unknown method: $method")
        }}.onSuccess { completion.ok(it) }.onFailure { completion.fail(it) }
    }
    private fun begin() { val a = activity ?: error("NFC requires an Activity context."); val n = adapter ?: error("NFC is unavailable."); check(n.isEnabled) { "NFC is disabled." }; a.runOnUiThread { n.disableReaderMode(a); n.enableReaderMode(a, this, NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V or NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS, null) } }
    private fun cancel() { pending = null; activity?.runOnUiThread { adapter?.disableReaderMode(activity) }; event(3) }
    override fun onTagDiscovered(tag: Tag) { runCatching { val ndef = Ndef.get(tag) ?: error("Tag does not support NDEF."); ndef.connect(); try { val write = pending; if (write != null) { check(ndef.isWritable) { "Tag is read-only." }; check(write.toByteArray().size <= ndef.maxSize) { "NDEF message exceeds tag capacity." }; ndef.writeNdefMessage(write); pending = null; event(2) } else event(1, records(ndef.ndefMessage)) } finally { ndef.close() }; activity?.runOnUiThread { adapter?.disableReaderMode(activity) } }.onFailure { event(4, message = it.message.orEmpty()) } }
    private fun message(json: String): NdefMessage { val rows = JSONArray(json); check(rows.length() in 1..128); return NdefMessage(Array(rows.length()) { i -> val r = rows.getJSONObject(i); NdefRecord(r.getInt("tnf").toShort(), decode(r, "typeBase64"), decode(r, "idBase64"), decode(r, "payloadBase64")) }) }
    private fun records(message: NdefMessage?): String { val out = JSONArray(); message?.records?.forEach { out.put(JSONObject().put("tnf", it.tnf.toInt()).put("typeBase64", encode(it.type)).put("idBase64", encode(it.id)).put("payloadBase64", encode(it.payload))) }; return out.toString() }
    private fun decode(v: JSONObject, key: String) = Base64.decode(v.getString(key), Base64.DEFAULT)
    private fun encode(v: ByteArray) = Base64.encodeToString(v, Base64.NO_WRAP)
    @Synchronized private fun event(kind: Int, records: String = "[]", message: String = "") { while (events.size >= 128) events.removeFirst(); events.addLast(JSONObject().put("kind", kind).put("recordsJson", records).put("message", message.take(1024))) }
    @Synchronized private fun poll(limit: Int) = JSONArray().also { out -> repeat(minOf(limit.coerceIn(1, 128), events.size)) { out.put(events.removeFirst()) } }
    private fun Map<String, WireValue>.text(k: String) = (get(k) as? WireValue.Text)?.value.orEmpty()
    private fun Map<String, WireValue>.integer(k: String) = (get(k) as? WireValue.Integer)?.value ?: 0
    private fun ModuleCompletion.ok(v: Map<String, WireValue> = emptyMap()) = complete(ModuleResultStatus.SUCCESS, WireMap.encode(v))
    private fun ModuleCompletion.fail(e: Throwable) = complete(ModuleResultStatus.FAILURE, e.message.orEmpty().take(1024).toByteArray())
}
