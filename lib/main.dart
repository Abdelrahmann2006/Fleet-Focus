import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/leader_ui_provider.dart';
import 'providers/telemetry_provider.dart';
import 'providers/participant_stream_provider.dart';
import 'constants/colors.dart';
import 'services/external_storage_service.dart';
import 'services/gist_command_service.dart';
import 'services/hive_blackbox_service.dart';
import 'services/log_batch_service.dart';
import 'services/sync_service.dart';
import 'utils/encryption_util.dart';

/// إشعارات محلية — للموبايل فقط (Android)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── ضبط خاص بالموبايل فقط ────────────────────────────────
  if (!kIsWeb) {
    // إجبار الاتجاه العمودي على الموبايل
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // تنسيق شريط الحالة
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // إعداد الإشعارات المحلية (Foreground Sticky Notification)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  // ─── Hive — Blackbox Offline Buffer ─────────────────────────
  if (!kIsWeb) {
    await Hive.initFlutter();
    await HiveBlackboxService.init();
  }

  // ─── Firebase ────────────────────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // تفعيل كاش RTDB للعمل offline
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10 * 1024 * 1024);
  } catch (e) {
    debugPrint('[Firebase] init error: $e');
  }

  // ─── التحقق من سلامة مفتاح التشفير ─────────────────────────
  // يُشغَّل في debug فقط — في release يعمل الـ AES صامتاً
  assert(EncryptionUtil.selfTest(), 'AES self-test فشل — تحقق من المفتاح');

  // ─── تهيئة خدمات التخزين الخارجي ─────────────────────────────
  // Telegram: المستودع الأساسي للصور والفيديو والصوت
  // Sheets:   أرشيف البيانات التاريخية (يُضاف لاحقاً بعد نشر Apps Script)
  // Pinata:   تخزين IPFS (يُضاف لاحقاً بعد الحصول على JWT)
  ExternalStorageService().configure(
    // ── Telegram (مُفعَّل) ─────────────────────────────────────
    telegramToken:   '8179961529:AAFXGEuTqXZONtgrXfD7HgFashDtxXwU21w',
    telegramChannel: '-1003674652029',

    // ── Google Sheets (يُكمَّل لاحقاً بعد نشر Apps Script) ────
    sheetsWebAppUrl: const String.fromEnvironment(
      'SHEETS_WEB_APP_URL', defaultValue: ''),
    sheetsId:        const String.fromEnvironment(
      'SHEETS_ID', defaultValue: ''),

    // ── YouTube (يُكمَّل لاحقاً) ───────────────────────────────
    youtubeAccessToken: const String.fromEnvironment(
      'YT_ACCESS_TOKEN', defaultValue: '') == ''
        ? null
        : const String.fromEnvironment('YT_ACCESS_TOKEN'),

    // ── Pinata / IPFS (يُكمَّل لاحقاً) ────────────────────────
    pinataJwt: const String.fromEnvironment(
      'PINATA_JWT', defaultValue: '') == ''
        ? null
        : const String.fromEnvironment('PINATA_JWT'),
  );

  // ─── Dead Pulse Protocol — GitHub Gist Fallback ────────────
  // عند انقطاع Firebase يُفحص Gist كل 15 دقيقة للأوامر الطارئة
  GistCommandService().configure(
    rawGistUrl: const String.fromEnvironment(
      'GIST_RAW_URL', defaultValue: ''),
    onCommand: (cmd) {
      debugPrint('[Gist] Emergency command received: $cmd');
      // يُوجَّه الأمر إلى CommandListenerService / NativeServiceChannel
    },
  );
  if (const String.fromEnvironment('GIST_RAW_URL', defaultValue: '').isNotEmpty) {
    GistCommandService().start();
  }

  // ─── Log Batch Service ──────────────────────────────────────
  LogBatchService().start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LeaderUIProvider()),
        ChangeNotifierProvider(create: (_) => TelemetryProvider()),
        // ── الجسر الحيوي: البيانات الحقيقية لبطاقات المشاركين ──
        ChangeNotifierProvider(create: (ctx) {
          final p = ParticipantStreamProvider();
          p.init();
          return p;
        }),
      ],
      child: const CompetitionApp(),
    ),
  );
}

class CompetitionApp extends StatelessWidget {
  const CompetitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'نظام المنافسة',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: _buildTheme(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Tajawal',
      useMaterial3: true,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.text),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
      ),
      // ── ويب: Scrollbar خفيف ─────────────────────────────
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.accent.withOpacity(0.3)),
        trackColor: WidgetStateProperty.all(AppColors.border),
        radius: const Radius.circular(4),
      ),
      // ── ويب: نمط الأزرار ─────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(
            fontFamily: 'Tajawal', color: AppColors.textSecondary),
        hintStyle:
            const TextStyle(fontFamily: 'Tajawal', color: AppColors.textMuted),
      ),
    );
  }
}
