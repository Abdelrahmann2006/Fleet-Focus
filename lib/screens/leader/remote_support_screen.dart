import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../constants/colors.dart';
import '../../services/webrtc_service.dart';

/// RemoteSupportScreen — شاشة الدعم الفني عن بُعد
///
/// تُتيح للمشرف فتح جلسة P2P WebRTC مع جهاز المشارك.
/// الجانب المرئي (فيديو المشرف) + الجانب الصوتي (صوت المشارك).
///
/// الاستخدام: /leader/remote-support?uid=<uid>
class RemoteSupportScreen extends StatefulWidget {
  final String uid;
  const RemoteSupportScreen({super.key, required this.uid});

  @override
  State<RemoteSupportScreen> createState() => _RemoteSupportScreenState();
}

class _RemoteSupportScreenState extends State<RemoteSupportScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  final _service = WebRtcService.instance;
  StreamSubscription? _remoteStreamSub;
  StreamSubscription? _localStreamSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _sessionSub;

  String _connectionStatus = 'غير متصل';
  String _sessionStatus = 'idle';
  bool _isLoading = false;
  bool _sessionActive = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _listenSessionStatus();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _localStreamSub = _service.onLocalStream.listen((stream) {
      setState(() => _localRenderer.srcObject = stream);
    });

    _remoteStreamSub = _service.onRemoteStream.listen((stream) {
      setState(() => _remoteRenderer.srcObject = stream);
    });

    _statusSub = _service.onStatus.listen((status) {
      setState(() => _connectionStatus = status);
    });
  }

  void _listenSessionStatus() {
    _sessionSub = FirebaseFirestore.instance
        .collection('webrtc_sessions')
        .doc(widget.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _sessionStatus = snap.data()?['status'] as String? ?? 'idle';
        _sessionActive = _sessionStatus == 'connected';
      });
    });
  }

  Future<void> _startSession() async {
    setState(() => _isLoading = true);
    try {
      await _service.startAdminSession(uid: widget.uid, videoEnabled: true);
      setState(() => _sessionActive = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل بدء الجلسة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _endSession() async {
    setState(() => _isLoading = true);
    await _service.hangup(widget.uid);
    setState(() {
      _sessionActive = false;
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    });
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _remoteStreamSub?.cancel();
    _localStreamSub?.cancel();
    _statusSub?.cancel();
    _sessionSub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundCard,
          title: const Text(
            'الدعم الفني عن بُعد',
            style: TextStyle(
              color: AppColors.accent,
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.accent),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            // ── شريط الحالة ──────────────────────────────────
            _buildStatusBar(),

            // ── منطقة الفيديو ────────────────────────────────
            Expanded(child: _buildVideoSection()),

            // ── أدوات التحكم ─────────────────────────────────
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final isConnected = _sessionStatus == 'connected';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: isConnected
          ? AppColors.success.withOpacity(0.15)
          : AppColors.warning.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isConnected ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _connectionStatus,
            style: TextStyle(
              color: isConnected ? AppColors.success : AppColors.warning,
              fontFamily: 'Tajawal',
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'UID: ${widget.uid.take(8)}...',
              style: const TextStyle(
                color: AppColors.accent,
                fontFamily: 'Tajawal',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Stack(
        children: [
          // ── الفيديو البعيد (المشارك) — يملأ الشاشة ──────────
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: _remoteRenderer.srcObject != null
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _sessionActive
                              ? Icons.videocam_off
                              : Icons.video_call_outlined,
                          color: AppColors.accent.withOpacity(0.4),
                          size: 64,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _sessionActive
                              ? 'في انتظار تدفق الفيديو...'
                              : 'ابدأ جلسة الدعم الفني',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // ── الفيديو المحلي (المشرف) — نافذة صغيرة ───────────
          if (_localRenderer.srcObject != null)
            Positioned(
              top: 12,
              left: 12,
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // ── معلومات الجلسة ────────────────────────────────
          if (_sessionStatus == 'calling')
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'في انتظار قبول المشارك...',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.accent.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          // ── معلومات الجلسة ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoChip(
                Icons.person,
                'المشارك',
                widget.uid.take(10),
                AppColors.info,
              ),
              _infoChip(
                Icons.security,
                'التشفير',
                'DTLS-SRTP',
                AppColors.success,
              ),
              _infoChip(
                Icons.router,
                'البروتوكول',
                'WebRTC P2P',
                AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── أزرار التحكم ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _sessionActive
                    ? ElevatedButton.icon(
                        onPressed: _isLoading ? null : _endSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.call_end, color: Colors.white),
                        label: const Text(
                          'إنهاء الجلسة',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _isLoading ? null : _startSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.video_call, color: Colors.white),
                        label: const Text(
                          'بدء جلسة الدعم',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Tajawal',
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontFamily: 'Tajawal',
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

extension on String {
  String take(int n) => length > n ? substring(0, n) : this;
}
