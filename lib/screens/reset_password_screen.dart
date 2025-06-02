import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String accessToken;

  const ResetPasswordScreen({super.key, required this.accessToken});

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final newPasswordController = TextEditingController();
  bool loading = false;

  Future<void> updatePassword() async {
    final newPassword = newPasswordController.text.trim();

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль должен быть не менее 6 символов')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сессия не активна. Повторите попытку.')),
        );
        return;
      }

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пароль успешно обновлён')),
        );

        context.go('/login'); 
      }
    } on AuthException catch (e) {
      if (e.message.contains("similar")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пароль слишком похож на предыдущий')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Смена пароля')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Введите новый пароль', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Новый пароль'),
            ),
            const SizedBox(height: 24),
            if (!loading)
              ElevatedButton(
                onPressed: updatePassword,
                child: const Text('Сменить пароль'),
              ),
            if (!loading)
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Вернуться к авторизации'),
              ),
            if (loading) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
