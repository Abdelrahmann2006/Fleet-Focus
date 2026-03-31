import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';

/// شاشة دردشات السيدة — 4 تبويبات:
/// 1. قناة السيدة (هي وحدها تكتب — العناصر يقرؤون فقط)
/// 2. مجموعة العناصر (هي تراقب + تفعيل/تعطيل)
/// 3. الدردشات الخاصة (بينها وبين أي عنصر)
/// 4. دردشات العناصر ببعض (مرئية لها)
class LeaderChatScreen extends StatefulWidget {
  const LeaderChatScreen({super.key});

  @override
  State<LeaderChatScreen> createState() => _LeaderChatScreenState();
}

class _LeaderChatScreenState extends State<LeaderChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
          isScrollable: true,
          labelStyle: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w700,
              fontSize: 12),
          tabs: const [
            Tab(text: 'قناة السيدة', icon: Icon(Icons.campaign_outlined, size: 18)),
            Tab(text: 'مجموعة العناصر', icon: Icon(Icons.group_outlined, size: 18)),
            Tab(text: 'خاص - عنصر', icon: Icon(Icons.chat_outlined, size: 18)),
            Tab(text: 'بين العناصر', icon: Icon(Icons.forum_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. قناة السيدة — هي وحدها تكتب
          _ChatTab(
            roomId: ChatService.broadcastRoomId(user.uid),
            senderUid: user.uid,
            senderName: user.fullName ?? 'السيدة',
            canWrite: true,
            mode: 'broadcast',
            leaderUid: user.uid,
            emptyMsg: 'أرسلي رسائلك لجميع العناصر هنا',
          ),
          // 2. مجموعة العناصر — السيدة تراقب فقط + تتحكم
          _ElementsGroupTab(leaderUid: user.uid, leaderName: user.fullName ?? 'السيدة'),
          // 3. خاص بين السيدة وعنصر
          _DirectChatsList(
            leaderUid: user.uid,
            leaderName: user.fullName ?? 'السيدة',
            type: 'direct_leader',
          ),
          // 4. دردشات بين العناصر
          _DirectChatsList(
            leaderUid: user.uid,
            leaderName: user.fullName ?? 'السيدة',
            type: 'direct_element',
            readOnly: true,
          ),
        ],
      ),
    );
  }
}

// ── تبويب الدردشة العامة ──────────────────────────────────────────
class _ChatTab extends StatefulWidget {
  final String roomId;
  final String senderUid;
  final String senderName;
  final bool canWrite;
  final String mode;
  final String leaderUid;
  final String emptyMsg;

  const _ChatTab({
    required this.roomId,
    required this.senderUid,
    required this.senderName,
    required this.canWrite,
    required this.mode,
    required this.leaderUid,
    required this.emptyMsg,
  });

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // إنشاء الغرفة إذا لم تكن موجودة
    if (widget.mode == 'broadcast') {
      ChatService().getOrCreateBroadcastRoom(widget.leaderUid);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatService().sendMessage(
        roomId: widget.roomId,
        senderUid: widget.senderUid,
        senderName: widget.senderName,
        text: text,
      );
      _msgCtrl.clear();
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ChatService().messagesStream(widget.roomId),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Text(widget.emptyMsg,
                      style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textMuted,
                          fontSize: 14)),
                );
              }
              return ListView.builder(
                controller: _scrollCtrl,
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final isMe = d['senderUid'] == widget.senderUid;
                  final ts = d['timestamp'] as Timestamp?;
                  final time = ts != null
                      ? _formatTime(ts.toDate())
                      : '';
                  return _MessageBubble(
                    text: d['text'] ?? '',
                    senderName: d['senderName'] ?? '',
                    time: time,
                    isMe: isMe,
                  );
                },
              );
            },
          ),
        ),
        if (widget.canWrite) _MessageInput(ctrl: _msgCtrl, onSend: _send, sending: _sending),
        if (!widget.canWrite)
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.backgroundCard,
            child: const Text(
              '👁 وضع المراقبة — لا يمكنك الكتابة هنا',
              style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textMuted,
                  fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── تبويب مجموعة العناصر ─────────────────────────────────────────
class _ElementsGroupTab extends StatefulWidget {
  final String leaderUid;
  final String leaderName;
  const _ElementsGroupTab({required this.leaderUid, required this.leaderName});

  @override
  State<_ElementsGroupTab> createState() => _ElementsGroupTabState();
}

class _ElementsGroupTabState extends State<_ElementsGroupTab> {
  bool _groupActive = true;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initRoom();
  }

  Future<void> _initRoom() async {
    await ChatService().getOrCreateElementsGroupRoom(widget.leaderUid);
    final doc = await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(ChatService.elementsGroupRoomId(widget.leaderUid))
        .get();
    if (mounted) {
      setState(() {
        _groupActive = doc.data()?['isActive'] ?? true;
        _initializing = false;
      });
    }
  }

  Future<void> _toggleGroup() async {
    final newActive = !_groupActive;
    await ChatService().toggleElementsRoom(widget.leaderUid, newActive);
    setState(() => _groupActive = newActive);
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    final roomId = ChatService.elementsGroupRoomId(widget.leaderUid);
    return Column(
      children: [
        // شريط التحكم
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.backgroundCard,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Switch(
                    value: _groupActive,
                    onChanged: (_) => _toggleGroup(),
                    activeColor: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _groupActive ? 'المجموعة مفعّلة' : 'المجموعة معطّلة',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: _groupActive
                          ? AppColors.accent
                          : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Text(
                '👁 وضع المراقبة',
                style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.textMuted,
                    fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: _groupActive
              ? _ChatTab(
                  roomId: roomId,
                  senderUid: widget.leaderUid,
                  senderName: widget.leaderName,
                  canWrite: false,
                  mode: 'monitor',
                  leaderUid: widget.leaderUid,
                  emptyMsg: 'لا توجد رسائل بعد في مجموعة العناصر',
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block,
                          color: AppColors.error.withOpacity(0.5), size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'المجموعة معطّلة\nالعناصر لا يستطيعون التواصل حالياً',
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
                ),
        ),
      ],
    );
  }
}

// ── قائمة المحادثات الخاصة ────────────────────────────────────────
class _DirectChatsList extends StatelessWidget {
  final String leaderUid;
  final String leaderName;
  final String type;
  final bool readOnly;

  const _DirectChatsList({
    required this.leaderUid,
    required this.leaderName,
    required this.type,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('leaderUid', isEqualTo: leaderUid)
          .where('type', isEqualTo: type)
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
                Text(
                  readOnly
                      ? 'لا توجد محادثات بين العناصر حتى الآن'
                      : 'لا توجد محادثات خاصة حتى الآن',
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textMuted,
                      fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (!readOnly) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _startNewChat(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('بدء محادثة',
                        style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w700)),
                  ),
                ],
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
            final otherUid = participants.firstWhere(
              (p) => p != leaderUid,
              orElse: () => '',
            ).toString();
            final otherName = names[otherUid] ?? 'عنصر';
            final lastMsg = d['lastMessage'] ?? 'ابدأ المحادثة';
            final lastTime = d['lastMessageAt'] as Timestamp?;

            return _RoomCard(
              name: otherName,
              lastMessage: lastMsg,
              time: lastTime != null ? _formatTime(lastTime.toDate()) : '',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _DirectChatRoom(
                    roomId: docs[i].id,
                    senderUid: leaderUid,
                    senderName: leaderName,
                    otherName: otherName,
                    canWrite: !readOnly,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startNewChat(BuildContext context) {
    // سيتم فتح شاشة اختيار العنصر
    // TODO: فتح قائمة العناصر للاختيار
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('افتح ملف العنصر وابدأ المحادثة منه',
            textAlign: TextAlign.right),
        backgroundColor: AppColors.backgroundCard,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}

// ── بطاقة غرفة ───────────────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final VoidCallback onTap;

  const _RoomCard({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                  Text(name,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        fontSize: 15,
                      )),
                  const SizedBox(height: 3),
                  Text(lastMessage,
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.accent.withOpacity(0.15),
                  child: Text(
                    name.isNotEmpty ? name[0] : 'ع',
                    style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(time,
                      style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textMuted,
                          fontSize: 10)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── غرفة محادثة مباشرة ───────────────────────────────────────────
class _DirectChatRoom extends StatefulWidget {
  final String roomId;
  final String senderUid;
  final String senderName;
  final String otherName;
  final bool canWrite;

  const _DirectChatRoom({
    required this.roomId,
    required this.senderUid,
    required this.senderName,
    required this.otherName,
    required this.canWrite,
  });

  @override
  State<_DirectChatRoom> createState() => _DirectChatRoomState();
}

class _DirectChatRoomState extends State<_DirectChatRoom> {
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
        senderUid: widget.senderUid,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
        title: Text(widget.otherName,
            style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
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
                            color: AppColors.textMuted)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final isMe = d['senderUid'] == widget.senderUid;
                    final ts = d['timestamp'] as Timestamp?;
                    return _MessageBubble(
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
          if (widget.canWrite) _MessageInput(ctrl: _msgCtrl, onSend: _send, sending: _sending),
          if (!widget.canWrite)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.backgroundCard,
              child: const Text(
                '👁 وضع المراقبة فقط',
                style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.textMuted,
                    fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

// ── فقاعة رسالة ──────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final String text;
  final String senderName;
  final String time;
  final bool isMe;

  const _MessageBubble({
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
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
                      height: 1.4)),
            ),
            Padding(
              padding: EdgeInsets.only(
                  top: 2,
                  left: isMe ? 4 : 0,
                  right: isMe ? 0 : 4),
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

// ── حقل إدخال الرسائل ────────────────────────────────────────────
class _MessageInput extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final bool sending;

  const _MessageInput({
    required this.ctrl,
    required this.onSend,
    required this.sending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border:
            Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
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
                            strokeWidth: 2, color: Colors.black),
                      ),
                    )
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
