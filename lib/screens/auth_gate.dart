import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  Session? _session;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;

    // 👇 Выполним очистку при первом входе
    _cleanupOldBookings();

    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      setState(() {
        _session = session;
      });

      // 👇 И при любом входе/выходе тоже
      if (event == AuthChangeEvent.signedIn) {
        _cleanupOldBookings();
      }

      print('**** onAuthStateChange: $event');
      print(session?.toJson());
    });
  }

  Future<void> _cleanupOldBookings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now().toUtc();

    try {
      await Supabase.instance.client
          .from('bookings')
          .update({
            'status': 'cancelled',
            'end_time': now.toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('status', 'active');
    } catch (e) {
      debugPrint('Ошибка очистки бронирований: $e');
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return LoginScreen();
    } else {
      return const MainScreen();
    }
  }
}
