import 'package:flutter/material.dart';
import 'package:car_rental_app/screens/map_screen.dart' as map;
import 'package:car_rental_app/screens/menu_screen.dart' as menu;
import 'package:car_rental_app/screens/profile_screen.dart' as profile;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; 

  final List<Widget> _screens = [
    const menu.MenuScreen(),
    const map.MapScreen(), 
    const profile.ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Меню'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Карта'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}
