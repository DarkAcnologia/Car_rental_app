import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = false;

  Future<void> _startPayment() async {
    setState(() => _loading = true);

    try {
      // 1. Запрос clientSecret
      final response = await http.post(
        Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': 1000, 'currency': 'usd'}),
      );

      if (response.statusCode != 200) throw Exception('Ошибка создания Intent');

      final data = jsonDecode(response.body);
      final clientSecret = data['clientSecret'];
      if (clientSecret == null) throw Exception('clientSecret отсутствует');

      // 2. Инициализация payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Car Sharing App',
          style: ThemeMode.system,
        ),
      );

      // 3. Открытие payment sheet
      await Stripe.instance.presentPaymentSheet();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Оплата прошла успешно')),
      );
    } on StripeException catch (e) {
      debugPrint('❌ Stripe отменена: ${e.error.localizedMessage}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Платёж отменён: ${e.error.localizedMessage}')),
      );
    } catch (e) {
      debugPrint('❌ Ошибка: $e');
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
                onPressed: _startPayment,
                child: const Text('Оплатить 10 USD'),
              ),
      ),
    );
  }
}
