import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:frontend/pages/start_page.dart';
import 'package:frontend/provider/user_info.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatelessWidget {
  final VoidCallback? onGoToSettings;

  const ProfilePage({Key? key, this.onGoToSettings}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userInfo = Provider.of<UserInfo>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                (user?.displayName ?? user?.email ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.displayName ?? 'User',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (user?.email != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                user!.email!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onGoToSettings,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              try {
                await GoogleSignIn.instance.signOut();
              } catch (_) {}
              userInfo.setUserId('');
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const StartPage()),
                (route) => false,
              );
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
