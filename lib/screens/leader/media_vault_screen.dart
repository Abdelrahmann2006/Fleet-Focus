import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';

/// MediaVaultScreen — خزنة الوسائط الأمنية للامتثال
///
/// تعرض أصول الامتثال المخزنة في Firestore:
///   - صور Snap Check-in (selfie + surroundings)
///   - سجلات DLP (تحذيرات تسرب البيانات)
///   - حزم المزامنة (Sync Dumps من Hive)
///   - روابط IPFS / Telegram لملفات خارجية
///
/// Firestore:
///   compliance_assets/{uid}/items       → صور + ملفات
///   compliance_assets/{uid}/dlp_alerts  → تحذيرات DLP
///   compliance_assets/{uid}/sync_dumps  → حزم المزامنة
///
/// الاستخدام: /leader/media-vault?uid=<uid>
class MediaVaultScreen extends StatefulWidget {
  final String uid;
  const MediaVaultScreen({super.key, required this.uid});

  @override
  State<MediaVaultScreen> createState() => _MediaVaultScreenState();
}

class _MediaVaultScreenState extends State<MediaVaultScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _selectedTab = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundCard,
          title: const Text(
            'خزنة الوسائط الأمنية',
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
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            labelStyle: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.camera_alt_outlined), text: 'التقاطات'),
              Tab(icon: Icon(Icons.shield_outlined), text: 'تحذيرات DLP'),
              Tab(icon: Icon(Icons.cloud_sync_outlined), text: 'مزامنة'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _SnapCheckinTab(uid: widget.uid),
            _DlpAlertsTab(uid: widget.uid),
            _SyncDumpsTab(uid: widget.uid),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 1: صور الـ Snap Check-in
// ─────────────────────────────────────────────────────────────

class _SnapCheckinTab extends StatelessWidget {
  final String uid;
  const _SnapCheckinTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection('items')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState(
            Icons.camera_alt_outlined,
            'لا توجد التقاطات بعد',
            'سيظهر هنا الصور المأخوذة عند أوامر التحقق من الهوية',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _SnapCheckinCard(data: data);
          },
        );
      },
    );
  }
}

class _SnapCheckinCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SnapCheckinCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'unknown';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final uploaded = data['uploaded'] as bool? ?? false;
    final telegramUrl = data['telegramUrl'] as String?;
    final ipfsUrl = data['ipfsUrl'] as String?;
    final localPath = data['localPath'] as String? ?? '';

    final isSelfie = type.contains('selfie');
    final timeStr = timestamp != null
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp)
        : 'غير معروف';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelfie
              ? AppColors.info.withOpacity(0.3)
              : AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelfie
                ? AppColors.info.withOpacity(0.15)
                : AppColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isSelfie ? Icons.face : Icons.panorama_outlined,
            color: isSelfie ? AppColors.info : AppColors.warning,
          ),
        ),
        title: Text(
          isSelfie ? 'صورة تحقق ذاتي' : 'صورة المحيط',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timeStr,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Tajawal',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _statusBadge(
                  uploaded ? 'مُرفوع' : 'محلي',
                  uploaded ? AppColors.success : AppColors.warning,
                ),
                if (telegramUrl != null) ...[
                  const SizedBox(width: 6),
                  _statusBadge('Telegram', AppColors.info),
                ],
                if (ipfsUrl != null) ...[
                  const SizedBox(width: 6),
                  _statusBadge('IPFS', AppColors.accent),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (telegramUrl != null)
              IconButton(
                icon: const Icon(Icons.link, color: AppColors.info, size: 18),
                onPressed: () => _copyUrl(context, telegramUrl),
                tooltip: 'نسخ رابط Telegram',
              ),
            if (ipfsUrl != null)
              IconButton(
                icon: const Icon(Icons.cloud, color: AppColors.accent, size: 18),
                onPressed: () => _copyUrl(context, ipfsUrl),
                tooltip: 'نسخ رابط IPFS',
              ),
          ],
        ),
      ),
    );
  }

  void _copyUrl(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الرابط'), backgroundColor: AppColors.success),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Tajawal',
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 2: تحذيرات DLP
// ─────────────────────────────────────────────────────────────

class _DlpAlertsTab extends StatelessWidget {
  final String uid;
  const _DlpAlertsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection('dlp_alerts')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState(
            Icons.shield_outlined,
            'لا توجد تحذيرات DLP',
            'سيظهر هنا أي نشاط مشبوه في تطبيقات عالية الخطورة',
          );
        }

        return Column(
          children: [
            // ملخص
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    '${docs.length} تحذير مكتشف',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _DlpAlertCard(data: data);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DlpAlertCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DlpAlertCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pkg = data['packageName'] as String? ?? 'مجهول';
    final keywords = (data['foundKeywords'] as List?)?.cast<String>() ?? [];
    final severity = data['severity'] as String? ?? 'MEDIUM';
    final snippet = data['textSnippet'] as String? ?? '';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final timeStr = timestamp != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
        : '';
    final isHigh = severity == 'HIGH';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHigh
              ? AppColors.error.withOpacity(0.4)
              : AppColors.warning.withOpacity(0.4),
        ),
      ),
      child: ExpansionTile(
        leading: Icon(
          Icons.gpp_bad,
          color: isHigh ? AppColors.error : AppColors.warning,
        ),
        title: Text(
          _packageToName(pkg),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '$timeStr • $severity',
          style: TextStyle(
            color: isHigh ? AppColors.error : AppColors.warning,
            fontFamily: 'Tajawal',
            fontSize: 12,
          ),
        ),
        iconColor: AppColors.accent,
        collapsedIconColor: AppColors.textSecondary,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (keywords.isNotEmpty) ...[
                  const Text(
                    'الكلمات المكتشفة:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: keywords
                        .map((k) => Chip(
                              label: Text(k,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'Tajawal',
                                    color: AppColors.error,
                                  )),
                              backgroundColor: AppColors.error.withOpacity(0.1),
                              side: BorderSide(
                                  color: AppColors.error.withOpacity(0.3)),
                              padding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                if (snippet.isNotEmpty) ...[
                  const Text(
                    'مقتطف النص:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      snippet.length > 200
                          ? '${snippet.substring(0, 200)}...'
                          : snippet,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'الحزمة: $pkg',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _packageToName(String pkg) {
    if (pkg.contains('whatsapp')) return 'واتساب';
    if (pkg.contains('telegram')) return 'تيليجرام';
    if (pkg.contains('firefox')) return 'فايرفوكس';
    if (pkg.contains('brave')) return 'بريف';
    if (pkg.contains('gmail')) return 'جيميل';
    if (pkg.contains('discord')) return 'ديسكورد';
    if (pkg.contains('outlook')) return 'أوتلوك';
    return pkg.split('.').last;
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 3: حزم المزامنة (Sync Dumps)
// ─────────────────────────────────────────────────────────────

class _SyncDumpsTab extends StatelessWidget {
  final String uid;
  const _SyncDumpsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection('sync_dumps')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState(
            Icons.cloud_sync_outlined,
            'لا توجد حزم مزامنة',
            'تظهر هنا السجلات المُرفوعة عند استعادة الاتصال بالإنترنت',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            final logCount = data['logCount'] as int? ?? 0;
            final sizeBytes = data['sizeBytes'] as int? ?? 0;
            final timeStr = timestamp != null
                ? DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp)
                : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: ListTile(
                leading: const Icon(Icons.folder_zip_outlined,
                    color: AppColors.accent),
                title: Text(
                  'حزمة مزامنة — $logCount سجل',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '$timeStr • ${_formatBytes(sizeBytes)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(Icons.check_circle,
                    color: AppColors.success, size: 20),
              ),
            );
          },
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── مساعدة: حالة فارغة ──────────────────────────────────────

Widget _emptyState(IconData icon, String title, String subtitle) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.accent.withOpacity(0.3), size: 72),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Tajawal',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Tajawal',
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
