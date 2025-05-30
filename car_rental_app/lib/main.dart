// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Optional: Log FCM token
  final fcmToken = await FirebaseMessaging.instance.getToken();
  print('📲 FCM Token: $fcmToken');

  FirebaseMessaging.onMessage.listen((message) {
    print('🔔 PUSH в активном режиме: ${message.notification?.title}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    print('📱 Открыто через уведомление: ${message.notification?.title}');
  });

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://jekylcxrzokwdjlknxjz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impla3lsY3hyem9rd2RqbGtueGp6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU3NzU4NjcsImV4cCI6MjA2MTM1MTg2N30.IWmmM-IK3xcCcxZVRG3CtQNBaoGnuvscsI42NHhbmro',
  );

  // Initialize Stripe
  Stripe.publishableKey = 'pk_test_51RU6hp2f1FykPDLPPZ7exqeEMeQUPqEHBMOEHmuXbA6qJ3O44KCe700pCAcCqFDhIGbt6KlYU89dXOoheq0Ivwje00iYwL3q6L'; // Замени на свой
  await Stripe.instance.applySettings(); 
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void updateTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client
          .from('profiles')
          .update({'theme': mode.name})
          .eq('id', user.id);
    }
  }

  Future<void> _loadUserTheme() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('theme')
          .eq('id', user.id)
          .maybeSingle();

      final theme = response?['theme'];
      if (theme == 'light') _themeMode = ThemeMode.light;
      else if (theme == 'dark') _themeMode = ThemeMode.dark;
      else _themeMode = ThemeMode.system;

      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Car Sharing App',
      themeMode: _themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      routerConfig: router,
    );
  }
}
