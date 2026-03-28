import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// LoyaltyEconomyService — محرك الثواب والعقاب الاقتصادي
///
/// • نقاط الولاء (Loyalty Coins) — تُكسَب عند الدقة الكاملة
/// • سجل الديون (Debt Ledger) — تُسجَّل عند الأخطاء
/// • تجميد الامتيازات — تلقائي عند ارتفاع الدين
/// • عقوبة مالية — تُسجَّل كمبلغ واقعي
///
/// البيانات مُخزَّنة في: economy/{uid}
class LoyaltyEconomyService {
  LoyaltyEconomyService._();
  static final instance = LoyaltyEconomyService._();

  static const _col = 'economy';

  // ── قراءة الحالة ─────────────────────────────────────────────────────────

  Stream<EconomyState> watchState(String uid) =>
      FirebaseFirestore.instance
          .collection(_col)
          .doc(uid)
          .snapshots()
          .map((s) => EconomyState.fromMap(s.data() ?? {}));

  Future<EconomyState> getState(String uid) async {
    final doc = await FirebaseFirestore.instance.collection(_col).doc(uid).get();
    return EconomyState.fromMap(doc.data() ?? {});
  }

  // ── إضافة نقاط ولاء ──────────────────────────────────────────────────────

  Future<void> awardCoins(String uid, int amount, String reason) async {
    await FirebaseFirestore.instance.collection(_col).doc(uid)
        .set({'coins': FieldValue.increment(amount)}, SetOptions(merge: true));
    await _logTransaction(uid, 'AWARD', amount, reason);
    _notifyRtdb(uid);
  }

  // ── إضافة دين ─────────────────────────────────────────────────────────────

  Future<void> addDebt(String uid, int amount, String reason) async {
    await FirebaseFirestore.instance.collection(_col).doc(uid).set({
      'debt':   FieldValue.increment(amount),
      'frozen': true,   // تجميد الامتيازات فوراً
    }, SetOptions(merge: true));
    await _logTransaction(uid, 'DEBT', amount, reason);
    // إشعار مستمر على الجهاز
    await FirebaseFirestore.instance
        .collection('device_commands')
        .doc(uid)
        .set({
      'command': 'show_debt_notification',
      'payload': {'amount': amount, 'reason': reason, 'persistent': true},
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    }, SetOptions(merge: false));
    _notifyRtdb(uid);
  }

  // ── سداد الدين ───────────────────────────────────────────────────────────

  Future<void> settleDebt(String uid, int amount) async {
    final state = await getState(uid);
    final remaining = (state.debt - amount).clamp(0, 999999);
    await FirebaseFirestore.instance.collection(_col).doc(uid).set({
      'debt':   remaining,
      'frozen': remaining > 0,
    }, SetOptions(merge: true));
    await _logTransaction(uid, 'SETTLE', amount, 'سداد دين');
    if (remaining == 0) {
      await FirebaseFirestore.instance
          .collection('device_commands')
          .doc(uid)
          .set({
        'command': 'dismiss_debt_notification',
        'payload': {},
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      }, SetOptions(merge: false));
    }
    _notifyRtdb(uid);
  }

  // ── عقوبة مالية ──────────────────────────────────────────────────────────

  Future<void> imposeFine(String uid, double amount, String currency) async {
    await FirebaseFirestore.instance.collection(_col).doc(uid).set({
      'monetaryFines': FieldValue.arrayUnion([{
        'amount':   amount,
        'currency': currency,
        'at':       Timestamp.now(),
        'cleared':  false,
      }]),
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance
        .collection('device_commands')
        .doc(uid)
        .set({
      'command': 'monetary_penalty_alert',
      'payload': {'amount': amount, 'currency': currency},
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    }, SetOptions(merge: false));
    _notifyRtdb(uid);
  }

  // ── التاريخ ─────────────────────────────────────────────────────────────

  Stream<List<EconomyTransaction>> watchHistory(String uid) =>
      FirebaseFirestore.instance
          .collection(_col)
          .doc(uid)
          .collection('transactions')
          .orderBy('at', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map(EconomyTransaction.fromDoc).toList());

  Future<void> _logTransaction(
      String uid, String type, int amount, String reason) async {
    await FirebaseFirestore.instance
        .collection(_col)
        .doc(uid)
        .collection('transactions')
        .add({
      'type':   type,
      'amount': amount,
      'reason': reason,
      'at':     FieldValue.serverTimestamp(),
    });
  }

  void _notifyRtdb(String uid) {
    FirebaseDatabase.instance
        .ref('device_states/$uid/economyChanged')
        .set(ServerValue.timestamp);
  }

  // ── الدرجة التراكمية الكاملة (Cumulative Master Score) ──────────────────

  Stream<int> watchMasterScore(String uid) =>
      FirebaseFirestore.instance
          .collection(_col)
          .doc(uid)
          .collection('transactions')
          .where('type', isEqualTo: 'AWARD')
          .snapshots()
          .map((s) => s.docs.fold(0, (sum, d) =>
              sum + ((d.data()['amount'] as num?)?.toInt() ?? 0)));
}

// ── النماذج ────────────────────────────────────────────────────────────────

class EconomyState {
  final int coins;
  final int debt;
  final bool frozen;
  final List<Map<String, dynamic>> monetaryFines;

  const EconomyState({
    required this.coins,
    required this.debt,
    required this.frozen,
    required this.monetaryFines,
  });

  factory EconomyState.fromMap(Map<String, dynamic> m) => EconomyState(
    coins:        (m['coins'] as num?)?.toInt() ?? 0,
    debt:         (m['debt']  as num?)?.toInt() ?? 0,
    frozen:       m['frozen'] as bool? ?? false,
    monetaryFines: (m['monetaryFines'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [],
  );
}

class EconomyTransaction {
  final String type;
  final int amount;
  final String reason;
  final DateTime? at;

  const EconomyTransaction({
    required this.type,
    required this.amount,
    required this.reason,
    this.at,
  });

  factory EconomyTransaction.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return EconomyTransaction(
      type:   m['type']   as String? ?? '',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      reason: m['reason'] as String? ?? '',
      at:     (m['at'] as Timestamp?)?.toDate(),
    );
  }
}
