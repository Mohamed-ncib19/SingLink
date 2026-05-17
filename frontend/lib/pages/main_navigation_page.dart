import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/pages/camera_screen.dart';
import 'package:frontend/pages/camera_screen_web.dart';
import 'package:frontend/pages/history.dart';
import 'package:frontend/pages/profile_page.dart';
import 'package:frontend/pages/settings.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({Key? key}) : super(key: key);

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    kIsWeb ? const CameraScreenWeb() : const CameraScreen(),
    const HistoryPage(),
    const _ProfileSection(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).primaryColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatefulWidget {
  const _ProfileSection({Key? key}) : super(key: key);

  @override
  _ProfileSectionState createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    if (_showSettings) {
      return MySettingsPage(
        onBack: () => setState(() => _showSettings = false),
      );
    }
    return ProfilePage(
      onGoToSettings: () => setState(() => _showSettings = true),
    );
  }
}
