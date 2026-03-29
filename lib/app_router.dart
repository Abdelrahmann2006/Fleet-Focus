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

// ── توضيح حالات نظام Panopticon ─────────────────────────────
// pending            → العنصر ربط الكود ويحتاج لملء الاستمارة
// submitted          → تم إرسال الاستمارة وفي انتظار قرار السيدة (Purgatory)
// rejected           → مرفوض نهائياً (شاشة المطهر مع رسالة الرفض)
// approved           → وافقت السيدة، شاشة الانتقال (الموت الرقمي) جاهزة
// approved_active    → اجتاز الطقوس، الجهاز تحت السيطرة الكاملة
// audit_active       → وضع الجرد الإلزامي (Kiosk)
// interview_locked   → قفل السيطرة المطلقة وقت المقابلة

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

    // ── 1. بوابة البيومترية (أولوية عليا) ──────────────────────
    if (auth.user?.biometricEnabled == true &&
        !auth.biometricVerified &&
        !_isBiometricExempt(loc)) {
      return '/auth/biometric-gate';
    }

    // ── 2. توجيه السيدة (القائد) ─────────────────────────────
    if (role == 'leader' && loc == '/') return '/leader/dashboard';

    // ── 3. توجيه العنصر (المشارك) ────────────────────────────
    if (role == 'participant') {
      final appStatus = auth.user?.applicationStatus ?? 'pending';
      final setupDone = auth.user?.deviceSetupComplete ?? false;

      // أ. مرحلة ملء الاستمارة (بعد إدخال الكود مباشرة)
      if (appStatus == 'pending') {
        return loc == '/participant/application' ? null : '/participant/application';
      }

      // ب. مرحلة الانتظار في "المطهر" (بعد إرسال الاستمارة أو عند الرفض)
      if (appStatus == 'submitted' || appStatus == 'rejected') {
        return loc == '/participant/purgatory' ? null : '/participant/purgatory';
      }

      // ج. مرحلة الموافقة الأولوية (شاشة الانتقال - الخطوة 2)
      if (appStatus == 'approved' && !setupDone) {
        return loc == '/participant/dying-transition' ? null : '/participant/dying-transition';
      }

      // د. أوضاع السيطرة الخاصة (الجرد، القفل، المقابلة)
      if (appStatus == 'audit_active') return loc == '/participant/asset-audit' ? null : '/participant/asset-audit';
      if (appStatus == 'interview_locked' || appStatus == 'audit_timeout') {
        return loc == '/participant/interview-lock' ? null : '/participant/interview-lock';
      }
      if (appStatus == 'final_constitution_active') {
        return loc == '/participant/final-constitution' ? null : '/participant/final-constitution';
      }

      // هـ. مرحلة تفعيل الصلاحيات والسيطرة التقنية
      if (!setupDone) {
        if (loc == '/participant/device-owner-setup' || loc == '/participant/permissions-flow') return null;
        return '/participant/device-setup';
      }

      // و. الوضع النهائي (الخضوع الكامل)
      if (loc == '/' || loc == '/participant/application' || loc == '/participant/purgatory') {
        return '/participant/home';
      }
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/auth/leader',      builder: (_, __) => const LeaderLoginScreen()),
    GoRoute(path: '/auth/participant', builder: (_, __) => const ParticipantLoginScreen()),
    GoRoute(path: '/auth/biometric-gate', builder: (_, __) => const BiometricGateScreen()),
    GoRoute(path: '/dying-ritual', builder: (_, __) => const DyingRitualScreen()),
    GoRoute(path: '/participant/dying-transition', builder: (_, __) => const DyingScreenTransition()),
    GoRoute(path: '/participant/device-owner-setup', builder: (_, __) => const DeviceOwnerSetupScreen()),
    GoRoute(path: '/participant/permissions-flow', builder: (_, __) => const PermissionsFlowScreen()),
    GoRoute(path: '/participant/asset-audit', builder: (_, __) => const AssetAuditScreen()),
    GoRoute(path: '/participant/interview-lock', builder: (_, __) => const InterviewLockScreen()),
    GoRoute(path: '/participant/final-constitution', builder: (_, __) => const FinalConstitutionScreen()),
    GoRoute(path: '/leader/dashboard', builder: (_, __) => const LeaderShell()),
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
      builder: (_, state) => DpcCommandCenterScreen(targetUid: state.uri.queryParameters['uid']),
    ),
    GoRoute(path: '/participant/home',         builder: (_, __) => const ParticipantHomeScreen()),
    GoRoute(path: '/participant/device-setup', builder: (_, __) => const DeviceSetupScreen()),
    GoRoute(path: '/participant/application',  builder: (_, __) => const ApplicationScreen()),
    GoRoute(path: '/participant/purgatory',    builder: (_, __) => const PurgatoryScreen()),
    GoRoute(path: '/participant/portal',       builder: (_, __) => const ParticipantSovereignPortal()),
    GoRoute(path: '/onboarding/constitution', builder: (_, __) => const ConstitutionScreen()),
    GoRoute(path: '/onboarding/signature',    builder: (_, __) => const SignatureScreen()),
    GoRoute(
      path: '/onboarding/countdown',
      builder: (_, state) => CountdownScreen(leaderName: state.uri.queryParameters['leader'] ?? 'السيدة'),
    ),
  ],
);
