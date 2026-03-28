import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRtcService — خدمة الدعم الفني عن بُعد P2P
///
/// تُوفر بنية WebRTC للتواصل المرئي بين المشرف والمشارك.
/// الإشارة (Signaling) تتم عبر Firestore (webrtc_sessions/{uid}).
///
/// قنوات البيانات (Data Channels):
///   - يُنشئ المشرف قناة بيانات عبر [openDataChannel] مع كل Offer.
///   - يستخدمها لنقل ملفات الامتثال الثقيلة (Hive dumps / SQLite exports)
///     مباشرة P2P دون الحاجة لـ Firebase.
///   - [sendComplianceDump] → يُرسل JSON مباشرة للمشارك.
///   - [onDataChannelMessage] → يُصدر الرسائل الواردة.
///
/// تدفق الجلسة (Admin side):
///   1. createOffer() → يُنشئ SDP Offer ويرفعه لـ Firestore
///   2. listenForAnswer() → يستمع لـ SDP Answer من المشارك
///   3. listenForIceCandidates() → يتبادل ICE Candidates
///   4. hangup() → يُنهي الجلسة
///
/// تدفق المشارك:
///   1. listenForOffer() → يستمع لطلب الجلسة
///   2. createAnswer() → يُنشئ SDP Answer
///   3. listenForIceCandidates() → يتبادل ICE Candidates
class WebRtcService {
  WebRtcService._();
  static final instance = WebRtcService._();

  static const _sessionsCollection = 'webrtc_sessions';

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // ── P2P Data Channel — نقل ملفات الامتثال مباشرة ─────────
  RTCDataChannel? _dataChannel;
  final _dataChannelMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _dataChannelStateController =
      StreamController<RTCDataChannelState>.broadcast();

  /// رسائل البيانات الواردة عبر Data Channel
  Stream<Map<String, dynamic>> get onDataChannelMessage =>
      _dataChannelMessageController.stream;

  /// حالة قناة البيانات (open / closed / connecting)
  Stream<RTCDataChannelState> get onDataChannelState =>
      _dataChannelStateController.stream;

  bool get isDataChannelOpen =>
      _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  final _localStreamController = StreamController<MediaStream>.broadcast();
  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  final _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<MediaStream> get onLocalStream => _localStreamController.stream;
  Stream<MediaStream> get onRemoteStream => _remoteStreamController.stream;
  Stream<RTCPeerConnectionState> get onConnectionState =>
      _connectionStateController.stream;
  Stream<String> get onStatus => _statusController.stream;

  StreamSubscription? _offerListener;
  StreamSubscription? _answerListener;
  StreamSubscription? _iceCandidateListener;

  bool get isConnected =>
      _peerConnection?.connectionState ==
      RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  // ── P2P Data Channel — فتح قناة البيانات (يُستدعى بعد initPeerConnection) ──

  /// يُنشئ قناة بيانات P2P لنقل ملفات الامتثال الثقيلة مباشرة.
  /// يجب استدعاؤه بعد [_initPeerConnection] وقبل إنشاء الـ Offer.
  Future<void> openDataChannel({String label = 'compliance_dump'}) async {
    final pc = _peerConnection;
    if (pc == null) {
      debugPrint('[WebRTC] لا يوجد PeerConnection — لا يمكن فتح Data Channel');
      return;
    }

    final init = RTCDataChannelInit()
      ..ordered   = true    // ضمان الترتيب (ملفات امتثال)
      ..maxRetransmits = 30; // إعادة المحاولة

    _dataChannel = await pc.createDataChannel(label, init);

    _dataChannel!.onDataChannelState = (state) {
      _dataChannelStateController.add(state);
      debugPrint('[WebRTC DataChannel] الحالة: $state');
    };

    _dataChannel!.onMessage = (RTCDataChannelMessage msg) {
      try {
        final decoded = jsonDecode(msg.text) as Map<String, dynamic>;
        _dataChannelMessageController.add(decoded);
        debugPrint('[WebRTC DataChannel] رسالة واردة: ${decoded["type"]}');
      } catch (e) {
        _dataChannelMessageController.add({'raw': msg.text});
      }
    };

    debugPrint('[WebRTC] ✓ Data Channel "$label" أُنشئت');
  }

  /// يُرسل تفريغ ملف امتثال (JSON) مباشرة للطرف الآخر P2P.
  ///
  /// [dumpType]    — نوع البيانات: "hive_blackbox" | "input_logs" | "activity_log"
  /// [jsonPayload] — البيانات كـ Map
  ///
  /// يُقسّم الحزم الكبيرة (> 16KB) تلقائياً إلى أجزاء (chunks).
  Future<void> sendComplianceDump({
    required String dumpType,
    required Map<String, dynamic> jsonPayload,
  }) async {
    if (_dataChannel == null || !isDataChannelOpen) {
      debugPrint('[WebRTC] Data Channel مغلقة — تعذّر إرسال $dumpType');
      return;
    }

    final envelope = jsonEncode({
      'type':      dumpType,
      'timestamp': DateTime.now().toIso8601String(),
      'payload':   jsonPayload,
    });

    const maxChunkSize = 16 * 1024; // 16 KB per chunk
    if (envelope.length <= maxChunkSize) {
      await _dataChannel!.send(RTCDataChannelMessage(envelope));
      debugPrint('[WebRTC] ✓ إرسال $dumpType (${envelope.length} bytes)');
    } else {
      final totalChunks = (envelope.length / maxChunkSize).ceil();
      for (var i = 0; i < totalChunks; i++) {
        final start = i * maxChunkSize;
        final end   = (start + maxChunkSize).clamp(0, envelope.length);
        final chunk = jsonEncode({
          'type':        'chunk',
          'dumpType':    dumpType,
          'chunkIndex':  i,
          'totalChunks': totalChunks,
          'data':        envelope.substring(start, end),
        });
        await _dataChannel!.send(RTCDataChannelMessage(chunk));
      }
      debugPrint('[WebRTC] ✓ إرسال $dumpType مقسّم على $totalChunks جزء');
    }
  }

  // ── تهيئة WebRTC ─────────────────────────────────────────

  Future<void> _initPeerConnection() async {
    final config = <String, dynamic>{
      'iceServers': [
        // ── STUN — Metered.ca (production) ────────────────────────────────
        {'urls': 'stun:stun.relay.metered.ca:80'},

        // ── TURN — Metered.ca Panopticon credentials ───────────────────────
        {
          'urls': [
            'turn:global.relay.metered.ca:80',
            'turn:global.relay.metered.ca:80?transport=tcp',
            'turn:global.relay.metered.ca:443?transport=tcp',
          ],
          'username':   '84d38a54adc8101e3dd909be',
          'credential': 'VNMkJcQTq1TnM/gY',
        },
        // ── TURNS over TLS — يخترق جدران الحماية الصارمة ──────────────────
        {
          'urls': 'turns:global.relay.metered.ca:443',
          'username':   '84d38a54adc8101e3dd909be',
          'credential': 'VNMkJcQTq1TnM/gY',
        },
      ],
      'sdpSemantics':         'unified-plan',
      'iceCandidatePoolSize': 10,
      'bundlePolicy':         'max-bundle',
      'rtcpMuxPolicy':        'require',
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onConnectionState = (state) {
      _connectionStateController.add(state);
      _statusController.add(_stateToArabic(state));
    };

    _peerConnection!.onIceCandidate = (candidate) {
      // يُعالج في المُستدعي
    };

    _peerConnection!.onAddStream = (stream) {
      _remoteStream = stream;
      _remoteStreamController.add(stream);
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamController.add(event.streams[0]);
      }
    };

    // استقبال Data Channel من الطرف الآخر (جانب المشارك)
    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = channel;

      _dataChannel!.onDataChannelState = (state) {
        _dataChannelStateController.add(state);
      };

      _dataChannel!.onMessage = (RTCDataChannelMessage msg) {
        try {
          final decoded = jsonDecode(msg.text) as Map<String, dynamic>;
          _dataChannelMessageController.add(decoded);
        } catch (e) {
          _dataChannelMessageController.add({'raw': msg.text});
        }
      };

      debugPrint('[WebRTC] ✓ Data Channel استُقبلت من الطرف الآخر');
    };
  }

  // ── جانب المشرف: إنشاء Offer ─────────────────────────────

  Future<void> startAdminSession({
    required String uid,
    bool videoEnabled = true,
  }) async {
    _statusController.add('جارٍ الاتصال...');
    await _initPeerConnection();

    // الحصول على الكاميرا والميكروفون
    _localStream = await navigator.mediaDevices.getUserMedia({
      'video': videoEnabled,
      'audio': true,
    });
    _localStreamController.add(_localStream!);

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // فتح Data Channel للتحويل P2P للملفات الثقيلة
    await openDataChannel(label: 'compliance_dump');

    // إنشاء SDP Offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // حفظ Offer في Firestore
    await FirebaseFirestore.instance
        .collection(_sessionsCollection)
        .doc(uid)
        .set({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'status': 'calling',
      'initiatedAt': FieldValue.serverTimestamp(),
    });

    // الاستماع لـ ICE Candidates من المشارك
    _listenForRemoteIceCandidates(uid, isAdmin: true);

    // الاستماع لـ Answer من المشارك
    _listenForAnswer(uid);

    _statusController.add('في انتظار المشارك...');
  }

  // ── جانب المشارك: الاستجابة لـ Offer ───────────────────

  Future<void> joinParticipantSession({
    required String uid,
    bool videoEnabled = false,
  }) async {
    _statusController.add('جارٍ الاتصال بالمشرف...');
    await _initPeerConnection();

    // الحصول على الميكروفون فقط (المشارك يُرسل صوت فقط)
    _localStream = await navigator.mediaDevices.getUserMedia({
      'video': videoEnabled,
      'audio': true,
    });
    _localStreamController.add(_localStream!);

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // قراءة Offer من Firestore
    final sessionDoc = await FirebaseFirestore.instance
        .collection(_sessionsCollection)
        .doc(uid)
        .get();

    final offerData = sessionDoc.data()?['offer'] as Map<String, dynamic>?;
    if (offerData == null) {
      _statusController.add('لا يوجد طلب اتصال نشط');
      return;
    }

    final offer =
        RTCSessionDescription(offerData['sdp'], offerData['type']);
    await _peerConnection!.setRemoteDescription(offer);

    // إنشاء Answer
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // رفع Answer لـ Firestore
    await FirebaseFirestore.instance
        .collection(_sessionsCollection)
        .doc(uid)
        .update({
      'answer': {'sdp': answer.sdp, 'type': answer.type},
      'status': 'connected',
    });

    // الاستماع لـ ICE Candidates من المشرف
    _listenForRemoteIceCandidates(uid, isAdmin: false);

    _statusController.add('متصل بالمشرف');
  }

  // ── ICE Candidates ────────────────────────────────────────

  void _listenForAnswer(String uid) {
    _answerListener?.cancel();
    _answerListener = FirebaseFirestore.instance
        .collection(_sessionsCollection)
        .doc(uid)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data()!;
      final answerData = data['answer'] as Map<String, dynamic>?;
      if (answerData == null) return;

      final remoteDesc = await _peerConnection!.getRemoteDescription();
      if (remoteDesc != null) return; // تم التعيين مسبقاً

      final answer =
          RTCSessionDescription(answerData['sdp'], answerData['type']);
      await _peerConnection!.setRemoteDescription(answer);
      _statusController.add('متصل بالمشارك');
    });
  }

  void _listenForRemoteIceCandidates(String uid, {required bool isAdmin}) {
    _iceCandidateListener?.cancel();
    final senderField = isAdmin ? 'participant' : 'admin';

    _iceCandidateListener = FirebaseFirestore.instance
        .collection(_sessionsCollection)
        .doc(uid)
        .collection('iceCandidates')
        .where('from', isEqualTo: senderField)
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          await _peerConnection!.addCandidate(candidate);
        }
      }
    });
  }

  Future<void> sendIceCandidate(
      String uid, RTCIceCandidate candidate, String from) async {
    await FirebaseFirestore.instance
        .collection(_sessionsCollection)
        .doc(uid)
        .collection('iceCandidates')
        .add({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
      'from': from,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── إنهاء الاتصال ─────────────────────────────────────────

  Future<void> hangup(String uid) async {
    _offerListener?.cancel();
    _answerListener?.cancel();
    _iceCandidateListener?.cancel();

    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;

    _dataChannel?.close();
    _dataChannel = null;

    await _peerConnection?.close();
    _peerConnection = null;

    await FirebaseFirestore.instance
        .collection(_sessionsCollection)
        .doc(uid)
        .update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()});

    _statusController.add('انتهى الاتصال');
    _connectionStateController.add(
        RTCPeerConnectionState.RTCPeerConnectionStateClosed);
  }

  void dispose() {
    _localStreamController.close();
    _remoteStreamController.close();
    _connectionStateController.close();
    _statusController.close();
    _dataChannelMessageController.close();
    _dataChannelStateController.close();
    _offerListener?.cancel();
    _answerListener?.cancel();
    _iceCandidateListener?.cancel();
  }

  String _stateToArabic(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        return 'جديد';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return 'جارٍ الاتصال...';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return '🟢 متصل';
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return '🔴 انقطع الاتصال';
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return '⛔ فشل الاتصال';
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return 'مغلق';
    }
  }
}
