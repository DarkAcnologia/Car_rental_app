import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'signup_screen.dart';
import 'change_password_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text,
        password: passwordController.text,
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        Provider.google,
        authScreenLaunchMode: LaunchMode.externalApplication,

      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка входа через Google')),
      );
    }
  }

  Future<void> logoutFromGoogle() async {
    const logoutUrl = 'https://accounts.google.com/logout';
    if (await canLaunchUrl(Uri.parse(logoutUrl))) {
      await launchUrl(Uri.parse(logoutUrl), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть logout-ссылку')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Вход')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Пароль'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChangePasswordScreen()),
                  );
                },
                child: Text('Забыли пароль?'),
              ),
            ),
            SizedBox(height: 10),
            loading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: login,
                    child: Text('Войти'),
                  ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: loginWithGoogle,
              icon: Icon(Icons.account_circle),
              label: Text('Войти через Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
            TextButton(
              onPressed: logoutFromGoogle,
              child: Text('Сменить Google-аккаунт'),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SignUpScreen()),
                );
              },
              child: Text("Нет аккаунта? Зарегистрироваться"),
            ),
          ],
        ),
      ),
    );
  }
}
