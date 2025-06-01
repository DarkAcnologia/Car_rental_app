import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = Supabase.instance.client.auth.currentUser;
  final _formKey = GlobalKey<FormState>();

  String? firstName;
  String? lastName;
  String? middleName;
  String? email;
  bool isVerified = false;
  String? faceUrl;
  String? licenseUrl;
  bool isLoading = true;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<String?> _getSignedUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final res = await Supabase.instance.client.storage
          .from('profile.uploads')
          .createSignedUrl(path, 60 * 60);
      return res;
    } catch (e) {
      print('Ошибка создания подписанной ссылки: $e');
      return null;
    }
  }

  Future<void> _loadProfile() async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user!.id)
        .maybeSingle();

    if (response != null) {
      final facePath = '${user!.id}/face.jpg';
      final licensePath = '${user!.id}/license.jpg';
      final signedFace = await _getSignedUrl(facePath);
      final signedLicense = await _getSignedUrl(licensePath);

      setState(() {
        firstName = response['first_name'];
        lastName = response['last_name'];
        middleName = response['middle_name'];
        email = response['email'] ?? user!.email;
        isVerified = response['is_verified'] ?? false;
        faceUrl = signedFace;
        licenseUrl = signedLicense;
        isLoading = false;
      });
    } else {
      setState(() {
        email = user!.email;
        isLoading = false;
      });
    }
  }

  Future<void> _pickImage(bool isLicense) async {
    try {
      final picker = ImagePicker();
      final result = await picker.pickImage(source: ImageSource.gallery);
      if (result == null) return;

      final file = File(result.path);
      final fileName = isLicense ? 'license.jpg' : 'face.jpg';
      final path = '${user!.id}/$fileName';

      await Supabase.instance.client.storage
          .from('profile.uploads')
          .uploadBinary(
            path,
            await file.readAsBytes(),
            fileOptions: const FileOptions(upsert: true),
          );

      final signedUrl = await _getSignedUrl(path);

      await Supabase.instance.client
          .from('profiles')
          .update({isLicense ? 'license_url' : 'face_url': path})
          .eq('id', user!.id);

      setState(() {
        if (isLicense) {
          licenseUrl = signedUrl;
        } else {
          faceUrl = signedUrl;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    await Supabase.instance.client.from('profiles').upsert({
      'id': user!.id,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'email': user!.email,
      'is_verified': false,
    });

    setState(() {
      isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль обновлён. Ожидайте подтверждения.')),
    );
  }

  void _startEditing() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Редактирование профиля'),
        content: const Text(
            'После редактирования потребуется повторное подтверждение администрацией. Продолжить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              setState(() => isEditing = true);
              Navigator.of(context).pop();
            },
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Почта: ${email ?? user!.email}', style: textStyle),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: lastName,
                decoration: const InputDecoration(labelText: 'Фамилия'),
                readOnly: !isEditing,
                onSaved: (val) => lastName = val,
                style: textStyle,
              ),
              TextFormField(
                initialValue: firstName,
                decoration: const InputDecoration(labelText: 'Имя'),
                readOnly: !isEditing,
                onSaved: (val) => firstName = val,
                style: textStyle,
              ),
              TextFormField(
                initialValue: middleName,
                decoration: const InputDecoration(labelText: 'Отчество'),
                readOnly: !isEditing,
                onSaved: (val) => middleName = val,
                style: textStyle,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (faceUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: Image.network(
                                faceUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Text('Ошибка загрузки'),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        const Text('Фото лица'),
                        const SizedBox(height: 4),
                        if (isEditing)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.upload),
                            label: const Text('Загрузить'),
                            onPressed: () => _pickImage(false),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        if (licenseUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: Image.network(
                                licenseUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Text('Ошибка загрузки'),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        const Text('Вод. удостоверение'),
                        const SizedBox(height: 4),
                        if (isEditing)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.upload),
                            label: const Text('Загрузить'),
                            onPressed: () => _pickImage(true),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isEditing ? _saveProfile : _startEditing,
                child: Text(isEditing ? 'Сохранить' : 'Редактировать'),
              ),
              const SizedBox(height: 12),
              if (!isVerified)
                const Text(
                  '⚠️ Данные ещё не подтверждены администрацией. Бронирование недоступно.',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
