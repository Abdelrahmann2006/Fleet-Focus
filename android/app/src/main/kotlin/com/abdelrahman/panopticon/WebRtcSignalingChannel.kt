package com.abdelrahman.panopticon

import android.content.Context
import android.util.Log
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * WebRtcSignalingChannel — قناة إشارات WebRTC عبر Firestore
 *
 * تُوفر بنية التحتية لـ P2P WebRTC:
 *   - تبادل SDP Offer/Answer
 *   - تبادل ICE Candidates
 *   - إدارة جلسة الدعم الفني عن بُعد
 *
 * Firestore Schema:
 *   webrtc_sessions/{uid}/
 *     - offer: {sdp, type}
 *     - answer: {sdp, type}
 *     - iceCandidates/{id}: {candidate, sdpMid, sdpMLineIndex}
 *     - status: "idle" | "calling" | "connected" | "ended"
 *     - initiatedAt: Timestamp
 *
 * يُسجَّل في MainActivity.configureFlutterEngine()
 */
class WebRtcSignalingChannel(
    private val context: Context,
    binaryMessenger: io.flutter.plugin.common.BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "WebRtcSignaling"
        const val CHANNEL_NAME = "com.abdelrahman.panopticon/webrtc_signaling"
        private const val SESSIONS_COLLECTION = "webrtc_sessions"
    }

    private val channel = MethodChannel(binaryMessenger, CHANNEL_NAME)
    private val db = FirebaseFirestore.getInstance()
    private var sessionListener: ListenerRegistration? = null

    init {
        channel.setMethodCallHandler(this)
        Log.i(TAG, "✓ WebRTC Signaling Channel جاهز")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val uid = call.argument<String>("uid") ?: run {
            result.error("MISSING_UID", "UID مطلوب", null)
            return
        }

        when (call.method) {
            "sendOffer" -> {
                val sdp = call.argument<String>("sdp") ?: return result.error("ERR", "SDP مطلوب", null)
                sendOffer(uid, sdp, result)
            }
            "sendAnswer" -> {
                val sdp = call.argument<String>("sdp") ?: return result.error("ERR", "SDP مطلوب", null)
                sendAnswer(uid, sdp, result)
            }
            "addIceCandidate" -> {
                val candidate = call.argument<String>("candidate") ?: return result.error("ERR", "Candidate مطلوب", null)
                val sdpMid = call.argument<String>("sdpMid") ?: ""
                val sdpMLineIndex = call.argument<Int>("sdpMLineIndex") ?: 0
                addIceCandidate(uid, candidate, sdpMid, sdpMLineIndex, result)
            }
            "listenForSession" -> {
                listenForSession(uid, result)
            }
            "endSession" -> {
                endSession(uid, result)
            }
            "createSession" -> {
                createSession(uid, result)
            }
            else -> result.notImplemented()
        }
    }

    // ── إنشاء جلسة WebRTC جديدة ──────────────────────────────

    private fun createSession(uid: String, result: MethodChannel.Result) {
        db.collection(SESSIONS_COLLECTION).document(uid)
            .set(mapOf(
                "status" to "calling",
                "initiatedAt" to com.google.firebase.Timestamp.now(),
                "adminInitiated" to true
            ))
            .addOnSuccessListener {
                Log.i(TAG, "✓ جلسة WebRTC أُنشئت لـ $uid")
                result.success("session_created")
            }
            .addOnFailureListener {
                result.error("FIRESTORE_ERROR", it.message, null)
            }
    }

    // ── إرسال SDP Offer ───────────────────────────────────────

    private fun sendOffer(uid: String, sdp: String, result: MethodChannel.Result) {
        db.collection(SESSIONS_COLLECTION).document(uid)
            .update(mapOf(
                "offer" to mapOf("sdp" to sdp, "type" to "offer"),
                "status" to "calling"
            ))
            .addOnSuccessListener {
                Log.i(TAG, "✓ SDP Offer أُرسل لـ $uid")
                result.success("offer_sent")
            }
            .addOnFailureListener {
                result.error("FIRESTORE_ERROR", it.message, null)
            }
    }

    // ── إرسال SDP Answer ──────────────────────────────────────

    private fun sendAnswer(uid: String, sdp: String, result: MethodChannel.Result) {
        db.collection(SESSIONS_COLLECTION).document(uid)
            .update(mapOf(
                "answer" to mapOf("sdp" to sdp, "type" to "answer"),
                "status" to "connected"
            ))
            .addOnSuccessListener {
                Log.i(TAG, "✓ SDP Answer أُرسل من $uid")
                result.success("answer_sent")
            }
            .addOnFailureListener {
                result.error("FIRESTORE_ERROR", it.message, null)
            }
    }

    // ── إضافة ICE Candidate ───────────────────────────────────

    private fun addIceCandidate(
        uid: String,
        candidate: String,
        sdpMid: String,
        sdpMLineIndex: Int,
        result: MethodChannel.Result
    ) {
        db.collection(SESSIONS_COLLECTION).document(uid)
            .collection("iceCandidates")
            .add(mapOf(
                "candidate" to candidate,
                "sdpMid" to sdpMid,
                "sdpMLineIndex" to sdpMLineIndex,
                "timestamp" to System.currentTimeMillis()
            ))
            .addOnSuccessListener {
                result.success("ice_added")
            }
            .addOnFailureListener {
                result.error("FIRESTORE_ERROR", it.message, null)
            }
    }

    // ── الاستماع للجلسة ───────────────────────────────────────

    private fun listenForSession(uid: String, result: MethodChannel.Result) {
        sessionListener?.remove()

        sessionListener = db.collection(SESSIONS_COLLECTION).document(uid)
            .addSnapshotListener { snap, error ->
                if (error != null) {
                    Log.e(TAG, "خطأ في الاستماع للجلسة: ${error.message}")
                    return@addSnapshotListener
                }
                if (snap == null || !snap.exists()) return@addSnapshotListener

                val sessionData = snap.data ?: return@addSnapshotListener

                // أرسل بيانات الجلسة لـ Flutter
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    try {
                        channel.invokeMethod("onSessionUpdate", sessionData.mapValues {
                            it.value?.toString() ?: ""
                        })
                    } catch (e: Exception) {
                        Log.w(TAG, "فشل إرسال تحديث الجلسة لـ Flutter: ${e.message}")
                    }
                }
            }

        result.success("listening")
    }

    // ── إنهاء الجلسة ─────────────────────────────────────────

    private fun endSession(uid: String, result: MethodChannel.Result) {
        sessionListener?.remove()
        sessionListener = null

        db.collection(SESSIONS_COLLECTION).document(uid)
            .update(mapOf(
                "status" to "ended",
                "endedAt" to com.google.firebase.Timestamp.now()
            ))
            .addOnSuccessListener {
                Log.i(TAG, "✓ جلسة WebRTC أُنهيت: $uid")
                result.success("session_ended")
            }
            .addOnFailureListener {
                result.error("FIRESTORE_ERROR", it.message, null)
            }
    }

    fun dispose() {
        sessionListener?.remove()
        channel.setMethodCallHandler(null)
    }
}
