import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  bool _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);

    try {
      // 1. Получаем clientSecret от Edge Function
      final response = await http.post(
        Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': 1000, // $10.00
          'currency': 'usd'
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200 || data['clientSecret'] == null) {
        throw Exception(data['error'] ?? 'Ошибка создания платежа');
      }

      final clientSecret = data['clientSecret'];

      // 2. Инициализируем Stripe Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'CarRental Inc.',
          style: ThemeMode.dark,
        ),
      );

      // 3. Открываем Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Оплата прошла успешно')),
      );
    } catch (e) {
      debugPrint('❌ Ошибка оплаты: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка оплаты: $e')),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оплата аренды')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _pay,
                child: const Text('Оплатить 10 USD'),
              ),
      ),
    );
  }
}
