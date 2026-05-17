import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:frontend/pages/start_page.dart';
import 'package:frontend/provider/user_info.dart';
import 'package:provider/provider.dart';

class MySettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const MySettingsPage({Key? key, this.onBack}) : super(key: key);

  @override
  _MySettingsPageState createState() => _MySettingsPageState();
}

class _MySettingsPageState extends State<MySettingsPage> {
  @override
  Widget build(BuildContext context) {
    final userInfo = Provider.of<UserInfo>(context);

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
        children: [
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Log out"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              try {
                await GoogleSignIn.instance.signOut();
              } catch (_) {}
              userInfo.setUserId('');
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
}
