import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';

/// شاشة دردشة العنصر — تعرض الغرف التي يمكنه الوصول إليها:
/// 1. قناة السيدة (قراءة فقط)
/// 2. مجموعة العناصر (إذا فعّلتها السيدة)
/// 3. المحادثات الخاصة معه
class ParticipantChatScreen extends StatefulWidget {
  const ParticipantChatScreen({super.key});

  @override
  State<ParticipantChatScreen> createState() => _ParticipantChatScreenState();
}

class _ParticipantChatScreenState extends State<ParticipantChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    final leaderUid = user.linkedLeaderUid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
        title: const Text(
          'المحادثات',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.text,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w700,
              fontSize: 12),
          tabs: const [
            Tab(text: 'قناة السيدة', icon: Icon(Icons.campaign_outlined, size: 18)),
            Tab(text: 'مجموعة العناصر', icon: Icon(Icons.group_outlined, size: 18)),
            Tab(text: 'الخاص', icon: Icon(Icons.chat_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. قناة السيدة — قراءة فقط
          _BroadcastChannel(
            roomId: ChatService.broadcastRoomId(leaderUid),
            currentUid: user.uid,
          ),
          // 2. مجموعة العناصر
          _ElementsGroupChannel(
            roomId: ChatService.elementsGroupRoomId(leaderUid),
            currentUid: user.uid,
            senderName: user.fullName ?? user.displayName,
          ),
          // 3. المحادثات الخاصة
          _PrivateChats(
            leaderUid: leaderUid,
            currentUid: user.uid,
            currentName: user.fullName ?? user.displayName,
          ),
        ],
      ),
    );
  }
}

// ── قناة السيدة (قراءة فقط) ──────────────────────────────────────
class _BroadcastChannel extends StatelessWidget {
  final String roomId;
  final String currentUid;
  const _BroadcastChannel({required this.roomId, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.accent.withOpacity(0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.campaign_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'قناة رسائل السيدة — للقراءة فقط',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ChatService().messagesStream(roomId),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          color: AppColors.textMuted, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد رسائل من السيدة بعد',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final ts = d['timestamp'] as Timestamp?;
                  return _ReadOnlyMessage(
                    text: d['text'] ?? '',
                    time: ts != null
                        ? '${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                        : '',
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── مجموعة العناصر ───────────────────────────────────────────────
class _ElementsGroupChannel extends StatefulWidget {
  final String roomId;
  final String currentUid;
  final String senderName;
  const _ElementsGroupChannel({
    required this.roomId,
    required this.currentUid,
    required this.senderName,
  });

  @override
  State<_ElementsGroupChannel> createState() => _ElementsGroupChannelState();
}

class _ElementsGroupChannelState extends State<_ElementsGroupChannel> {
  final _msgCtrl = TextEditingController();
  bool _sending = false;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _checkRoomStatus();
  }

  Future<void> _checkRoomStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .get();
      if (mounted) {
        setState(() => _isActive = doc.data()?['isActive'] ?? false);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatService().sendMessage(
        roomId: widget.roomId,
        senderUid: widget.currentUid,
        senderName: widget.senderName,
        text: text,
      );
      _msgCtrl.clear();
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isActive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            const Text(
              'المجموعة معطّلة حالياً\nالسيدة لم تفعّل التواصل بين العناصر',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ChatService().messagesStream(widget.roomId),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                    child: Text('ابدأ المحادثة مع بقية العناصر...',
                        style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: AppColors.textMuted)));
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final isMe = d['senderUid'] == widget.currentUid;
                  final ts = d['timestamp'] as Timestamp?;
                  return _ChatBubble(
                    text: d['text'] ?? '',
                    senderName: d['senderName'] ?? '',
                    time: ts != null
                        ? '${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                        : '',
                    isMe: isMe,
                  );
                },
              );
            },
          ),
        ),
        _MessageInput(ctrl: _msgCtrl, onSend: _send, sending: _sending),
      ],
    );
  }
}

// ── محادثات خاصة للعنصر ──────────────────────────────────────────
class _PrivateChats extends StatelessWidget {
  final String leaderUid;
  final String currentUid;
  final String currentName;
  const _PrivateChats({
    required this.leaderUid,
    required this.currentUid,
    required this.currentName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('participants', arrayContains: currentUid)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    color: AppColors.textMuted, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'لا توجد محادثات خاصة حتى الآن',
                  style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textMuted,
                      fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final names = d['names'] as Map<String, dynamic>? ?? {};
            final participants = d['participants'] as List? ?? [];
            final otherUid = participants
                .firstWhere((p) => p != currentUid, orElse: () => '')
                .toString();
            final otherName =
                names[otherUid] ?? (otherUid == leaderUid ? 'السيدة' : 'عنصر');
            final lastMsg = d['lastMessage'] ?? 'ابدأ المحادثة';
            final lastTime = d['lastMessageAt'] as Timestamp?;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _DirectRoom(
                    roomId: docs[i].id,
                    currentUid: currentUid,
                    currentName: currentName,
                    otherName: otherName,
                    isLeader: otherUid == leaderUid,
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chevron_left, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (otherUid == leaderUid)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('السيدة',
                                      style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          color: AppColors.accent,
                                          fontSize: 10)),
                                ),
                              Text(otherName,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                    fontSize: 15,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(lastMsg,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: otherUid == leaderUid
                              ? AppColors.accent.withOpacity(0.2)
                              : AppColors.backgroundElevated,
                          child: Text(
                            otherName.isNotEmpty ? otherName[0] : 'س',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: otherUid == leaderUid
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (lastTime != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${lastTime.toDate().day}/${lastTime.toDate().month}',
                            style: const TextStyle(
                                fontFamily: 'Tajawal',
                                color: AppColors.textMuted,
                                fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── غرفة محادثة مباشرة ───────────────────────────────────────────
class _DirectRoom extends StatefulWidget {
  final String roomId;
  final String currentUid;
  final String currentName;
  final String otherName;
  final bool isLeader;

  const _DirectRoom({
    required this.roomId,
    required this.currentUid,
    required this.currentName,
    required this.otherName,
    required this.isLeader,
  });

  @override
  State<_DirectRoom> createState() => _DirectRoomState();
}

class _DirectRoomState extends State<_DirectRoom> {
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatService().sendMessage(
        roomId: widget.roomId,
        senderUid: widget.currentUid,
        senderName: widget.currentName,
        text: text,
      );
      _msgCtrl.clear();
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isLeader)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('السيدة',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.accent,
                        fontSize: 11)),
              ),
            Text(widget.otherName,
                style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ChatService().messagesStream(widget.roomId),
              builder: (ctx, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                      child: Text('ابدأ المحادثة...',
                          style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppColors.textMuted)));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final isMe = d['senderUid'] == widget.currentUid;
                    final ts = d['timestamp'] as Timestamp?;
                    return _ChatBubble(
                      text: d['text'] ?? '',
                      senderName: d['senderName'] ?? '',
                      time: ts != null
                          ? '${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                          : '',
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          _MessageInput(ctrl: _msgCtrl, onSend: _send, sending: _sending),
        ],
      ),
    );
  }
}

// ── مكونات مساعدة ────────────────────────────────────────────────
class _ReadOnlyMessage extends StatelessWidget {
  final String text;
  final String time;
  const _ReadOnlyMessage({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(time,
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textMuted,
                      fontSize: 11)),
              Row(
                children: [
                  const Text('السيدة',
                      style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Icon(Icons.campaign_rounded,
                      color: AppColors.accent, size: 14),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.text,
                  fontSize: 14,
                  height: 1.4),
              textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final String senderName;
  final String time;
  final bool isMe;
  const _ChatBubble({
    required this.text,
    required this.senderName,
    required this.time,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, right: 4),
                child: Text(senderName,
                    style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.backgroundCard
                    : AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 4 : 16),
                  bottomRight: Radius.circular(isMe ? 16 : 4),
                ),
                border: Border.all(
                  color: isMe
                      ? AppColors.border
                      : AppColors.accent.withOpacity(0.3),
                ),
              ),
              child: Text(text,
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.text,
                      fontSize: 14,
                      height: 1.4),
                  textAlign: TextAlign.right),
            ),
            Padding(
              padding:
                  EdgeInsets.only(top: 2, left: isMe ? 4 : 0, right: isMe ? 0 : 4),
              child: Text(time,
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textMuted,
                      fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final bool sending;
  const _MessageInput(
      {required this.ctrl, required this.onSend, required this.sending});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(
            top: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: sending
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black)))
                  : const Icon(Icons.send, color: Colors.black, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.text,
                  fontSize: 14),
              decoration: InputDecoration(
                hintText: 'اكتب رسالة...',
                hintStyle: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.textMuted,
                    fontSize: 13),
                filled: true,
                fillColor: AppColors.backgroundElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
        ],
      ),
    );
  }
}
