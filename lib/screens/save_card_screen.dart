import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class SaveCardScreen extends StatefulWidget {
  const SaveCardScreen({super.key});

  @override
  State<SaveCardScreen> createState() => _SaveCardScreenState();
}

class _SaveCardScreenState extends State<SaveCardScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _cards = [];
  String? _selectedCardId;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final res = await Supabase.instance.client
        .from('payment_methods')
        .select()
        .eq('user_id', userId);

    if (res != null && res is List) {
      final cards = List<Map<String, dynamic>>.from(res);

      for (var card in cards) {
        final methodId = card['stripe_payment_method_id'];
        final stripeDetails = await _getStripeCardDetails(methodId);
        card['brand'] = stripeDetails['card']?['brand'] ?? 'unknown';
        card['last4'] = stripeDetails['card']?['last4'] ?? '****';
      }

      setState(() {
        _cards = cards;
        _selectedCardId = _cards.firstWhere(
          (card) => card['is_primary'] == true,
          orElse: () => _cards.isNotEmpty ? _cards.first : <String, dynamic>{},
        )['id'];
      });
    }
  }

  Future<Map<String, dynamic>> _getStripeCardDetails(String methodId) async {
    final response = await http.post(
      Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/get-card-details'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'payment_method_id': methodId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      debugPrint('Ошибка получения данных карты: ${response.body}');
      return {};
    }
  }

  Future<void> _deleteCard(String cardId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить карту?'),
        content: const Text('Вы уверены, что хотите удалить эту карту?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final card = _cards.firstWhere((c) => c['id'] == cardId);
      if (card['is_primary'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нельзя удалить основную карту')),
        );
        return;
      }

      await Supabase.instance.client
          .from('payment_methods')
          .delete()
          .eq('id', cardId);

      await _loadCards();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Карта удалена')),
      );
    } catch (e) {
      debugPrint('Ошибка удаления: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления карты: $e')),
      );
    }
  }

  Future<void> _saveCard() async {
    setState(() => _loading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Пользователь не авторизован');

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('stripe_customer_id, email')
          .eq('id', userId)
          .single();

      if (profile['stripe_customer_id'] == null) {
        final response = await http.post(
          Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/create-stripe-customer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'email': profile['email'],
          }),
        );

        final data = jsonDecode(response.body);
        if (response.statusCode != 200 || data['stripe_customer_id'] == null) {
          throw Exception(data['error'] ?? 'Ошибка создания Stripe Customer');
        }
      }

      final response = await http.post(
        Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/create-setup-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200 || data['clientSecret'] == null) {
        throw Exception(data['error'] ?? 'Ошибка создания SetupIntent');
      }

      final clientSecret = data['clientSecret'];
      final setupIntentId = data['setupIntentId'];

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          merchantDisplayName: 'Car Sharing App',
          style: ThemeMode.system,
          allowsDelayedPaymentMethods: true,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      final methodIdResponse = await http.post(
        Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/get-payment-method-id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'setup_intent_id': setupIntentId}),
      );

      final methodIdData = jsonDecode(methodIdResponse.body);
      if (methodIdResponse.statusCode != 200 || methodIdData['stripe_payment_method_id'] == null) {
        throw Exception(methodIdData['error'] ?? 'Не удалось получить payment_method');
      }

      final paymentMethodId = methodIdData['stripe_payment_method_id'];

      final updateResponse = await http.post(
        Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/update-payment-method'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'stripe_payment_method_id': paymentMethodId,
        }),
      );

      final updateData = jsonDecode(updateResponse.body);
      if (updateResponse.statusCode != 200) {
        throw Exception(updateData['error'] ?? 'Ошибка сохранения карты');
      }

      await _loadCards();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Карта успешно сохранена')),
      );
    } catch (e) {
      final message = e is Exception ? e.toString() : 'Неизвестная ошибка';
      debugPrint('❌ Ошибка: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $message')),
      );
    }

    setState(() => _loading = false);
  }

  Widget _buildCardItem(Map<String, dynamic> card) {
    final brand = (card['brand'] ?? 'card').toString().toUpperCase();
    final last4 = card['last4'] ?? '****';
    final isSelected = _selectedCardId == card['id'];

    return ListTile(
      leading: const Icon(Icons.credit_card),
      title: Text('$brand **** **** **** $last4'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected) const Icon(Icons.check_circle, color: Colors.green),
          if (!isSelected)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCard(card['id']),
            ),
        ],
      ),
      onTap: () async {
        setState(() => _selectedCardId = card['id']);

        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await Supabase.instance.client.from('payment_methods').update({
            'is_primary': false,
          }).eq('user_id', userId);

          await Supabase.instance.client.from('payment_methods').update({
            'is_primary': true,
          }).eq('id', card['id']);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Способы оплаты')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                children: [
                  ElevatedButton(
                    onPressed: _saveCard,
                    child: const Text('Добавить карту'),
                  ),
                  Expanded(
                    child: ListView(
                      children: _cards.map(_buildCardItem).toList(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
