import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/supabase_service.dart';
import 'auth/login_screen.dart';
import 'auth/splash_screen.dart';
import 'common/layouts/main_tab_layout.dart';
import 'home/home_screen.dart';
import 'my/my_page_screen.dart';
import 'onboarding/data_connection_screen.dart';
import 'onboarding/goal_setting_screen.dart';
import 'onboarding/profile_setup_screen.dart';
import 'onboarding/race_record_input_screen.dart';
import 'onboarding/running_experience_screen.dart';
import 'plan/plan_create_screen.dart';
import 'plan/plan_detail_screen.dart';
import 'plan/plan_screen.dart';
import 'plan/session_detail_screen.dart';
import 'plan/weekly_review_screen.dart';
import 'records/records_screen.dart';
import 'records/workout_detail_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Auth 스트림을 Listenable로 변환하여 GoRouter refresh에 사용
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// GoRouter를 Riverpod Provider로 관리
final routerProvider = Provider<GoRouter>((ref) {
  final authStream = SupabaseService.client.auth.onAuthStateChange;
  final refreshListenable = GoRouterRefreshStream(authStream);

  ref.onDispose(() => refreshListenable.dispose());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) async {
      // Strava OAuth 콜백 딥링크는 app_links 리스너가 처리하므로
      // go_router에서는 기존 화면으로 리다이렉트 (루트 경로 체크보다 먼저)
      final uri = state.uri.toString();
      if (uri.contains('strava-callback')) {
        final prefs = await SharedPreferences.getInstance();
        final onboardingDone =
            prefs.getBool('onboarding_completed') ?? false;
        return onboardingDone ? '/home' : '/onboarding/data-connection';
      }

      // 루트 경로 → splash로 리다이렉트 (auth 상태에 따라 재분기)
      if (state.matchedLocation == '/') {
        return '/splash';
      }

      final session = SupabaseService.client.auth.currentSession;
      final isLoggedIn = session != null;

      final currentPath = state.matchedLocation;
      final isOnSplash = currentPath == '/splash';
      final isOnLogin = currentPath == '/login';
      final isOnOnboarding = currentPath.startsWith('/onboarding');
      final isAuthRoute = isOnSplash || isOnLogin;

      // 미로그인 → login 화면으로
      if (!isLoggedIn) {
        if (isOnLogin) return null;
        return '/login';
      }

      // 로그인 상태에서 splash → 온보딩 완료 체크
      if (isOnSplash) {
        final prefs = await SharedPreferences.getInstance();
        final onboardingDone =
            prefs.getBool('onboarding_completed') ?? false;
        if (onboardingDone) return '/home';
        return '/onboarding/profile';
      }

      // 로그인 상태에서 login 화면 → 온보딩 체크
      if (isOnLogin) {
        final prefs = await SharedPreferences.getInstance();
        final onboardingDone =
            prefs.getBool('onboarding_completed') ?? false;
        if (onboardingDone) return '/home';
        return '/onboarding/profile';
      }

      // 온보딩 중이면 그대로 유지
      if (isOnOnboarding) return null;

      // 로그인 + 메인 화면 → 온보딩 완료 체크
      if (!isAuthRoute && !isOnOnboarding) {
        final prefs = await SharedPreferences.getInstance();
        final onboardingDone =
            prefs.getBool('onboarding_completed') ?? false;
        if (!onboardingDone) return '/onboarding/profile';
      }

      return null;
    },
    routes: [
      // 스플래시
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      // 로그인
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // 온보딩
      GoRoute(
        path: '/onboarding/profile',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/experience',
        builder: (context, state) => const RunningExperienceScreen(),
      ),
      GoRoute(
        path: '/onboarding/data-connection',
        builder: (context, state) => const DataConnectionScreen(),
      ),
      GoRoute(
        path: '/onboarding/race-records',
        builder: (context, state) => const RaceRecordInputScreen(),
      ),
      GoRoute(
        path: '/onboarding/goal',
        builder: (context, state) => const GoalSettingScreen(),
      ),

      // ─── 상세 화면 (루트 레벨, 탭 바 없이 push) ───
      GoRoute(
        path: '/plan/session/:sessionId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return SessionDetailScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/plan/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PlanCreateScreen(),
      ),
      // D-3 주간 리뷰
      GoRoute(
        path: '/plan/weekly-review/:weekId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final weekId = state.pathParameters['weekId']!;
          return WeeklyReviewScreen(weekId: weekId);
        },
      ),
      GoRoute(
        path: '/plan/detail/:planId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          return PlanDetailScreen(planId: planId);
        },
      ),
      // D-2 운동 기록 상세
      GoRoute(
        path: '/records/:workoutId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final workoutId = state.pathParameters['workoutId']!;
          return WorkoutDetailScreen(workoutId: workoutId);
        },
      ),

      // ─── 메인 탭 ───
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainTabLayout(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/records',
                builder: (context, state) => const RecordsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const MyPageScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
