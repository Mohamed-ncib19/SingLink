import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:frontend/pages/start_page.dart';
import 'package:frontend/provider/theme_model.dart';
import 'package:frontend/provider/user_info.dart';
import 'package:provider/provider.dart';
import 'package:frontend/const/custom_theme.dart';

class MySettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const MySettingsPage({Key? key, this.onBack}) : super(key: key);

  @override
  _MySettingsPageState createState() => _MySettingsPageState();
}

class _MySettingsPageState extends State<MySettingsPage> {
  void _showFontSizePopUp(ThemeNotifier themeNotifier) async {
    await showDialog<double>(
      context: context,
      builder: (context) => FontSizePopUp(
        initialFontSize: themeNotifier.getFontSize(),
        themeNotifier: themeNotifier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final userInfo = Provider.of<UserInfo>(context);
    themeNotifier.getTheme;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: <Widget>[
          _buildSettingTile(
            icon: Icons.mode_night_outlined,
            title: "Dark/Light Mode",
            onTap: () => themeNotifier.changeThemeMode(),
          ),
          _buildSettingTile(
            icon: Icons.border_color_outlined,
            title: "Theme Color",
            onTap: () => chooseThemeColor(themeNotifier),
          ),
          _buildSettingTile(
            icon: Icons.format_size_sharp,
            title: "Text Size",
            onTap: () => _showFontSizePopUp(themeNotifier),
          ),
          const Divider(height: 32, indent: 16, endIndent: 16),
          _buildSettingTile(
            icon: userInfo.getUserId.isEmpty ? Icons.login : Icons.logout,
            title: userInfo.getUserId.isEmpty ? "Login" : "Log out",
            onTap: () async {
              if (userInfo.getUserId.isNotEmpty) {
                await FirebaseAuth.instance.signOut();
                try {
                  await GoogleSignIn.instance.signOut();
                } catch (_) {}
                userInfo.setUserId('');
              }
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const StartPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void chooseThemeColor(ThemeNotifier themeNotifier) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Choose Theme Color"),
          content: Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              colorCircle(themeNotifier, Colors.pink, 'pink'),
              colorCircle(themeNotifier, defaultColor, 'default'),
              colorCircle(themeNotifier, Colors.orange, 'orange'),
              colorCircle(themeNotifier, Colors.brown, 'brown'),
              colorCircle(themeNotifier, Colors.lightBlue, 'lightBlue'),
              colorCircle(themeNotifier, Colors.purple, 'purple'),
            ],
          ),
        );
      },
    );
  }

  Widget colorCircle(
      ThemeNotifier themeNotifier, MaterialColor color, String colorString) {
    return GestureDetector(
      onTap: () => themeNotifier.setThemeColor(color, colorString),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
      ),
    );
  }
}

class FontSizePopUp extends StatefulWidget {
  final double initialFontSize;
  final ThemeNotifier themeNotifier;

  const FontSizePopUp(
      {Key? key, required this.initialFontSize, required this.themeNotifier})
      : super(key: key);

  @override
  _FontSizePopUpState createState() => _FontSizePopUpState();
}

class _FontSizePopUpState extends State<FontSizePopUp> {
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.initialFontSize;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Font Size'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Slider(
            value: _fontSize,
            max: 30,
            min: 10,
            divisions: 20,
            label: _fontSize.round().toString(),
            onChanged: (double value) {
              setState(() {
                _fontSize = value;
                widget.themeNotifier.setFontSize(_fontSize);
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            "SignLink",
            style: TextStyle(fontSize: _fontSize),
          ),
        ],
      ),
    );
  }
}
