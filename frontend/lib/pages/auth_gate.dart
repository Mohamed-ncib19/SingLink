import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:frontend/pages/start_page.dart';
import 'package:frontend/pages/translation_page.dart';
import 'package:frontend/provider/user_info.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const StartPage();

        final userInfo = Provider.of<UserInfo>(context, listen: false);
        if (userInfo.getUserId != user.uid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            userInfo.setUserId(user.uid);
          });
        }

        return const TranslationPage();
      },
    );
  }
}
