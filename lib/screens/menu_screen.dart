import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';
import 'package:car_rental_app/state/trip_state.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  ThemeMode selectedMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('theme')
          .eq('id', user.id)
          .maybeSingle();

      final theme = res?['theme'];
      setState(() {
        if (theme == 'light') selectedMode = ThemeMode.light;
        else if (theme == 'dark') selectedMode = ThemeMode.dark;
        else selectedMode = ThemeMode.system;
      });
    }
  }

  void _logout() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      final now = DateTime.now().toUtc();

      await Supabase.instance.client
          .from('bookings')
          .update({
            'status': 'cancelled',
            'end_time': now.toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('status', 'active');
    }

    final trip = TripState();
    trip
      ..activeCar = null
      ..startTime = null
      ..totalPrice = 0.0
      ..isPaused = false;
    trip.priceTimer?.cancel();

    await Supabase.instance.client.auth.signOut();

    if (mounted) {
      context.go('/login');
    }
  }

  void _toggleTheme(ThemeMode mode) {
    setState(() => selectedMode = mode);
    MyApp.of(context)?.updateTheme(mode);
  }

  Widget _buildThemeSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 55,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildThemeButton('АВТО', ThemeMode.system),
          _buildThemeIcon(Icons.wb_sunny_outlined, ThemeMode.light),
          _buildThemeIcon(Icons.nightlight_round, ThemeMode.dark),
        ],
      ),
    );
  }

  Widget _buildThemeButton(String label, ThemeMode mode) {
    final isSelected = selectedMode == mode;
    return GestureDetector(
      onTap: () => _toggleTheme(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(30))
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeIcon(IconData icon, ThemeMode mode) {
    final isSelected = selectedMode == mode;
    return GestureDetector(
      onTap: () => _toggleTheme(mode),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: isSelected
            ? BoxDecoration(color: Colors.blue, shape: BoxShape.circle)
            : null,
        child: Icon(icon, color: isSelected ? Colors.white : Colors.black),
      ),
    );
  }

  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('О приложении'),
        content: const Text(
          'Приложение "CarRentalApp" предназначено для аренды автомобилей. '
          'Вы можете бронировать машины, просматривать историю поездок, '
          'добавлять карты и оплачивать аренду.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОК')),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Меню')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            _buildThemeSwitcher(),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Способ оплаты'),
              onTap: () => context.push('/save-card'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('История бронирований'),
              onTap: () => context.push('/history'),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Выйти из аккаунта'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: _logout,
            ),
            const Divider(height: 32),
            const Text(
              '📋 Информация',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('О приложении'),
              onTap: _showAboutApp,
            ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Условия использования'),
              onTap: () => context.push('/terms'),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Инструкция'),
              onTap: () => context.push('/user-guide'),
            ),
          ],
        ),
      ),
    );
  }
}
