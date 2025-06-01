import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/auth_gate.dart';
import 'screens/reset_password_screen.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/filter_screen.dart';
import 'screens/booking_history_screen.dart';
import 'screens/map_screen.dart';
import 'screens/payment_method_screen.dart';
import 'screens/save_card_screen.dart';
import 'screens/instruction_screen.dart';
import 'screens/terms_of_use_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) => const MainScreen(),
      routes: [
        GoRoute(
          path: 'map', // Это будет /main/map
          builder: (context, state) {
            final extra = state.extra;
            final filters = extra is Map
                ? Map<String, dynamic>.from(extra)
                : <String, dynamic>{};
            return MapScreen(initialFilters: filters);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => ResetPasswordScreen(
        accessToken: state.uri.queryParameters['access_token'] ?? '',
      ),
    ),
    GoRoute(
      path: '/filters',
      builder: (context, state) {
        final extra = state.extra;
        final filters = extra is Map
            ? Map<String, dynamic>.from(extra)
            : <String, dynamic>{};
        return FilterScreen(initialFilters: filters);
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const BookingHistoryScreen(),
    ),
    GoRoute(
  path: '/save-card',
  builder: (context, state) => const SaveCardScreen(),
),
GoRoute(
  path: '/user-guide',
  builder: (context, state) => const InstructionScreen(),
),
GoRoute(
  path: '/terms',
  builder: (context, state) => const TermsOfUseScreen(),
),
    GoRoute(
  path: '/payment-method',
  builder: (context, state) => const PaymentMethodScreen(),
),
  ],
);
