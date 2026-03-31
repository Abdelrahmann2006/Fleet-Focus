import 'package:cloud_firestore/cloud_firestore.dart';

/// ChatService — خدمة الدردشة عبر Firestore
///
/// أنواع المحادثات:
/// 1. group_broadcast   — السيدة تتكلم للجميع (read-only للعناصر)
/// 2. group_elements    — العناصر مع بعض (السيدة تراقب فقط)
/// 3. direct_leader     — محادثة خاصة بين السيدة وعنصر واحد
/// 4. direct_element    — محادثة خاصة بين عنصرين (مرئية للسيدة)
class ChatService {
  static final ChatService _i = ChatService._();
  factory ChatService() => _i;
  ChatService._();

  final _db = FirebaseFirestore.instance;

  // ── مجموعات Firestore ─────────────────────────────────────────
  CollectionReference get _chatRooms => _db.collection('chat_rooms');
  CollectionReference _messages(String roomId) =>
      _db.collection('chat_rooms').doc(roomId).collection('messages');

  // ── معرفات الغرف الثابتة ──────────────────────────────────────
  static String broadcastRoomId(String leaderUid) =>
      'broadcast_${leaderUid}';
  static String elementsGroupRoomId(String leaderUid) =>
      'elements_group_${leaderUid}';
  static String directRoomId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return 'direct_${sorted[0]}_${sorted[1]}';
  }

  // ── إنشاء/الحصول على غرفة ────────────────────────────────────
  Future<String> getOrCreateBroadcastRoom(String leaderUid) async {
    final id = broadcastRoomId(leaderUid);
    await _chatRooms.doc(id).set({
      'type': 'group_broadcast',
      'leaderUid': leaderUid,
      'name': 'قناة السيدة',
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    }, SetOptions(merge: true));
    return id;
  }

  Future<String> getOrCreateElementsGroupRoom(String leaderUid) async {
    final id = elementsGroupRoomId(leaderUid);
    await _chatRooms.doc(id).set({
      'type': 'group_elements',
      'leaderUid': leaderUid,
      'name': 'مجموعة العناصر',
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'isMonitored': true,
    }, SetOptions(merge: true));
    return id;
  }

  Future<String> getOrCreateDirectRoom({
    required String uid1,
    required String uid2,
    required String name1,
    required String name2,
    required String leaderUid,
    required String type, // 'direct_leader' | 'direct_element'
  }) async {
    final id = directRoomId(uid1, uid2);
    await _chatRooms.doc(id).set({
      'type': type,
      'participants': [uid1, uid2],
      'names': {uid1: name1, uid2: name2},
      'leaderUid': leaderUid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return id;
  }

  // ── إرسال رسالة ──────────────────────────────────────────────
  Future<void> sendMessage({
    required String roomId,
    required String senderUid,
    required String senderName,
    required String text,
    String? imageUrl,
  }) async {
    await _messages(roomId).add({
      'senderUid': senderUid,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [senderUid],
    });
    // تحديث آخر رسالة في الغرفة
    await _chatRooms.doc(roomId).update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderName': senderName,
    });
  }

  // ── قراءة الرسائل ─────────────────────────────────────────────
  Stream<QuerySnapshot> messagesStream(String roomId, {int limit = 50}) {
    return _messages(roomId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  // ── وضع علامة مقروء ──────────────────────────────────────────
  Future<void> markRead(String roomId, String messageId, String uid) async {
    await _messages(roomId).doc(messageId).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }

  // ── عدد الرسائل غير المقروءة ──────────────────────────────────
  Stream<int> unreadCountStream(String roomId, String uid) {
    return _messages(roomId)
        .where('readBy', arrayContains: uid)
        .snapshots()
        .map((snap) => 0); // سنستخدم نهجاً أبسط
  }

  // ── تفعيل/تعطيل غرفة العناصر ─────────────────────────────────
  Future<void> toggleElementsRoom(String leaderUid, bool isActive) async {
    final id = elementsGroupRoomId(leaderUid);
    await _chatRooms.doc(id).update({'isActive': isActive});
  }

  // ── قائمة الغرف للسيدة ───────────────────────────────────────
  Stream<QuerySnapshot> leaderRoomsStream(String leaderUid) {
    return _chatRooms
        .where('leaderUid', isEqualTo: leaderUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  // ── قائمة الغرف للعنصر ───────────────────────────────────────
  Stream<QuerySnapshot> participantRoomsStream(String leaderUid, String uid) {
    return _chatRooms
        .where('leaderUid', isEqualTo: leaderUid)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }
}
