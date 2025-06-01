import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class SharedPaymentScreen extends StatefulWidget {
  final String bookingId;
  final List<Map<String, dynamic>> contributors;

  const SharedPaymentScreen({
    super.key,
    required this.bookingId,
    required this.contributors,
  });

  @override
  State<SharedPaymentScreen> createState() => _SharedPaymentScreenState();
}

class _SharedPaymentScreenState extends State<SharedPaymentScreen> {
  List<Map<String, dynamic>> paymentLinks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _processPayments();
  }

  Future<void> _processPayments() async {
    final supabase = Supabase.instance.client;
    final supabaseUrl = supabase.restUrl;
    final supabaseKey = supabase.supabaseKey;

    final List<Map<String, dynamic>> links = [];

    for (final c in widget.contributors) {
      final splitId = const Uuid().v4();

      final insertRes = await http.post(
        Uri.parse('$supabaseUrl/split_payments'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'id': splitId,
          'booking_id': widget.bookingId,
          'contributor_name': c['name'],
          'amount': c['amount'],
          'is_paid': false,
        }),
      );

      if (insertRes.statusCode != 201) continue;

      final splitRes = await http.post(
        Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/create-split-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'split_payment_id': splitId}),
      );

      final result = jsonDecode(splitRes.body);
      if (splitRes.statusCode == 200 && result['url'] != null) {
        links.add({
          'name': c['name'],
          'amount': c['amount'],
          'link': result['url'],
        });
      }
    }

    setState(() {
      paymentLinks = links;
      isLoading = false;
    });
  }

  void _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await launcher.canLaunchUrl(uri)) {
      await launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована')),
    );
  }

  void _shareLink(String name, double amount, String url) {
    final message = 'Ссылка для оплаты ($name, ${amount.toStringAsFixed(2)} ₽):\n$url';
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Разделение счёта')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: paymentLinks.length,
              itemBuilder: (context, index) {
                final item = paymentLinks[index];
                final url = item['link'] as String;
                final name = item['name'];
                final amount = item['amount'];

                return Card(
                  margin: const EdgeInsets.all(12),
                  color: isDark ? Colors.grey[900] : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$name — ${amount.toStringAsFixed(2)} ₽',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: QrImageView(
                              data: url,
                              size: 160,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              tooltip: 'Скопировать',
                              onPressed: () => _copyLink(url),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_browser),
                              tooltip: 'Открыть',
                              onPressed: () => _openLink(url),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share),
                              tooltip: 'Поделиться',
                              onPressed: () => _shareLink(name, amount, url),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}