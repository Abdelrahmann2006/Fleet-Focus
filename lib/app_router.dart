import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/leader_login_screen.dart';
import 'screens/auth/participant_login_screen.dart';
import 'screens/auth/biometric_gate_screen.dart';
import 'screens/leader/leader_shell.dart';
import 'screens/leader/participants_screen.dart';
import 'screens/leader/participant_detail_screen.dart';
import 'screens/leader/device_management_screen.dart';
import 'screens/leader/device_detail_screen.dart';
import 'screens/leader/dpc_command_center_screen.dart';
import 'screens/participant/home_screen.dart';
import 'screens/participant/device_setup_screen.dart';
import 'screens/participant/application_screen.dart';
import 'screens/participant/purgatory_screen.dart';
import 'screens/participant/participant_sovereign_portal_screen.dart';
import 'screens/participant/dying_ritual_screen.dart';
import 'screens/participant/dying_screen_transition.dart';
import 'screens/participant/device_owner_setup_screen.dart';
import 'screens/participant/permissions_flow_screen.dart';
import 'screens/participant/asset_audit_screen.dart';
import 'screens/participant/interview_lock_screen.dart';
import 'screens/participant/final_constitution_screen.dart';
import 'screens/onboarding/constitution_screen.dart';
import 'screens/onboarding/signature_screen.dart';
import 'screens/onboarding/countdown_screen.dart';

// ── مسارات مُعفاة من بوابة البيومترية ───────────────────────────
const _biometricExemptPaths = {
  '/',
  '/auth/leader',
  '/auth/participant',
  '/auth/biometric-gate',
  '/dying-ritual',
  '/participant/dying-transition',
  '/participant/device-owner-setup',
  '/participant/permissions-flow',
  '/participant/interview-lock',
};

bool _isBiometricExempt(String loc) {
  if (_biometricExemptPaths.contains(loc)) return true;
  if (loc.startsWith('/onboarding/')) return true;
  return false;
}

// ── حالات العنصر ─────────────────────────────────────────────
// pending            → في انتظار موافقة السيدة (Purgatory)
// rejected           → مرفوض (Purgatory + بيانات محلية تُمسح)
// approved           → موافَق عليه، شاشة الانتقال لم تُعرض بعد
// approved_active    → اجتاز الانتقال، في وضع عمل طبيعي
// audit_active       → وضع الجرد (Kiosk)
// audit_submitted    → تم إرسال الجرد
// audit_timeout      → انتهى وقت الجرد → قفل عقابي
// interview_locked   → AlarmManager أطلق القفل المطلق وقت المقابلة
// final_constitution_active → الدستور النهائي جاهز للتوقيع

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isLoading) return null;

    final isLoggedIn = auth.user != null;
    final role = auth.user?.role;
    final loc  = state.uri.toString();

    if (!isLoggedIn) {
      if (loc == '/' || loc.startsWith('/auth')) return null;
      return '/';
    }

    // ── بوابة البيومترية (أولوية عليا) ──────────────────────
    if (auth.user?.biometricEnabled == true &&
        !auth.biometricVerified &&
        !_isBiometricExempt(loc)) {
      return '/auth/biometric-gate';
    }

    // ── توجيه السيدة (القائد) ─────────────────────────────
    if (role == 'leader' && loc == '/') return '/leader/dashboard';

    // ── توجيه العنصر (المشارك) ────────────────────────────
    if (role == 'participant') {
      final appStatus = auth.user?.applicationStatus ?? 'pending';
      final setupDone = auth.user?.deviceSetupComplete ?? false;

      // مسارات مُعفاة من إعادة التوجيه
      if (loc == '/dying-ritual' || loc == '/participant/portal') return null;

      // ── 1. مُعلَّق أو مرفوض → Purgatory ─────────────────
      if (appStatus == 'pending' || appStatus == 'rejected') {
        return loc == '/participant/purgatory' ? null : '/participant/purgatory';
      }

      // ── 2. موافَق مبدئياً → شاشة الانتقال (Step 2) ───────
      if (appStatus == 'approved' && !setupDone) {
        return loc == '/participant/dying-transition'
            ? null
            : '/participant/dying-transition';
      }

      // ── 3. وضع الجرد (Kiosk — Step 3) ────────────────────
      if (appStatus == 'audit_active') {
        return loc == '/participant/asset-audit'
            ? null
            : '/participant/asset-audit';
      }

      // ── 4. قفل انتهاء وقت الجرد ──────────────────────────
      if (appStatus == 'audit_timeout') {
        return loc == '/participant/interview-lock'
            ? null
            : '/participant/interview-lock';
      }

      // ── 5. قفل المقابلة (Step 4a) ─────────────────────────
      if (appStatus == 'interview_locked') {
        return loc == '/participant/interview-lock'
            ? null
            : '/participant/interview-lock';
      }

      // ── 6. الدستور النهائي (Step 4b) ──────────────────────
      if (appStatus == 'final_constitution_active') {
        return loc == '/participant/final-constitution'
            ? null
            : '/participant/final-constitution';
      }

      // ── 7. تهيئة الجهاز لم تكتمل بعد ────────────────────
      if (!setupDone) {
        if (loc == '/participant/device-owner-setup') return null;
        if (loc == '/participant/permissions-flow') return null;
        return loc == '/participant/device-setup'
            ? null
            : '/participant/device-setup';
      }

      // ── 8. وضع عادي — توجيه للرئيسية ─────────────────────
      if (loc == '/') return '/participant/home';
      if (loc == '/participant/device-setup') return '/participant/home';
      if (loc == '/participant/purgatory') return '/participant/home';
      if (loc == '/participant/dying-transition') return '/participant/home';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/auth/leader',      builder: (_, __) => const LeaderLoginScreen()),
    GoRoute(path: '/auth/participant', builder: (_, __) => const ParticipantLoginScreen()),

    // ── بوابة المصادقة البيومترية ────────────────────────────
    GoRoute(path: '/auth/biometric-gate', builder: (_, __) => const BiometricGateScreen()),

    // ── طقس الرحيل الرقمي (الخروج النهائي) ──────────────────
    GoRoute(path: '/dying-ritual', builder: (_, __) => const DyingRitualScreen()),

    // ── شاشة الانتقال عند الموافقة (Step 2) ─────────────────
    GoRoute(path: '/participant/dying-transition', builder: (_, __) => const DyingScreenTransition()),

    // ── إعداد Device Owner (بين الانتقال وإعداد الجهاز) ──────
    GoRoute(path: '/participant/device-owner-setup', builder: (_, __) => const DeviceOwnerSetupScreen()),

    // ── تدفق الصلاحيات (بعد Device Owner وقبل إعداد الجهاز) ──
    GoRoute(path: '/participant/permissions-flow', builder: (_, __) => const PermissionsFlowScreen()),

    // ── نموذج الجرد الشامل (Kiosk — Step 3) ─────────────────
    GoRoute(path: '/participant/asset-audit', builder: (_, __) => const AssetAuditScreen()),

    // ── قفل المقابلة (Step 4a) ───────────────────────────────
    GoRoute(path: '/participant/interview-lock', builder: (_, __) => const InterviewLockScreen()),

    // ── الدستور النهائي (Step 4b) ────────────────────────────
    GoRoute(path: '/participant/final-constitution', builder: (_, __) => const FinalConstitutionScreen()),

    // ── السيدة — Shell مع Bottom Nav ─────────────────────────
    GoRoute(path: '/leader/dashboard', builder: (_, __) => const LeaderShell()),

    // مسارات السيدة الفرعية
    GoRoute(path: '/leader/participants', builder: (_, __) => const ParticipantsScreen()),
    GoRoute(
      path: '/leader/participant/:uid',
      builder: (_, state) => ParticipantDetailScreen(uid: state.pathParameters['uid']!),
    ),
    GoRoute(path: '/leader/devices', builder: (_, __) => const DeviceManagementScreen()),
    GoRoute(
      path: '/leader/device/:uid',
      builder: (_, state) => DeviceDetailScreen(uid: state.pathParameters['uid']!),
    ),
    GoRoute(
      path: '/leader/dpc',
      builder: (_, state) => DpcCommandCenterScreen(
        targetUid: state.uri.queryParameters['uid'],
      ),
    ),

    // ── العنصر ──────────────────────────────────────────────
    GoRoute(path: '/participant/home',         builder: (_, __) => const ParticipantHomeScreen()),
    GoRoute(path: '/participant/device-setup', builder: (_, __) => const DeviceSetupScreen()),
    GoRoute(path: '/participant/application',  builder: (_, __) => const ApplicationScreen()),
    GoRoute(path: '/participant/purgatory',    builder: (_, __) => const PurgatoryScreen()),
    GoRoute(path: '/participant/portal',       builder: (_, __) => const ParticipantSovereignPortal()),

    // ── Onboarding (نموذج الطلب) ─────────────────────────────
    GoRoute(path: '/onboarding/constitution', builder: (_, __) => const ConstitutionScreen()),
    GoRoute(path: '/onboarding/signature',    builder: (_, __) => const SignatureScreen()),
    GoRoute(
      path: '/onboarding/countdown',
      builder: (_, state) {
        final leaderName = state.uri.queryParameters['leader'] ?? 'السيدة';
        return CountdownScreen(leaderName: leaderName);
      },
    ),
  ],
);
