import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final user = Supabase.instance.client.auth.currentUser;
  List<Map<String, dynamic>> bookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final response = await Supabase.instance.client
        .from('bookings')
        .select('*, cars(*)')
        .eq('user_id', user!.id)
        .order('start_time', ascending: false);

    setState(() {
      bookings = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  Future<void> _payDebt(String bookingId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final res = await http.post(
      Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/create-payment-intent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'booking_id': bookingId,
      }),
    );

    final result = jsonDecode(res.body);
    if (res.statusCode == 200 && result['payment_status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Оплата прошла успешно')),
      );
      _loadBookings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Ошибка оплаты: ${result['error'] ?? 'Неизвестно'}')),
      );
    }
  }

  void _showCarDetails(Map<String, dynamic> car) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            if (car['image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  car['image_url'],
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 10),
            Text(
              car['name'] ?? 'Без названия',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 6),
            Text(car['description'] ?? 'Описание недоступно', style: TextStyle(color: textColor)),
            const SizedBox(height: 6),
            Text('Цена за минуту: ${car['price_per_minute']} ₽', style: TextStyle(color: textColor)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История бронирований')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookings.isEmpty
              ? const Center(child: Text('Бронирования отсутствуют.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    final car = booking['cars'];
                    final paymentStatus = booking['payment_status'];
                    final total = booking['total_price'] ?? 0;
                    final unpaidAmount = booking['unpaid_amount'] ?? 0;

                    Color tileColor;
                    if (paymentStatus == 'success') {
                      tileColor = Colors.green.withOpacity(0.1);
                    } else if (paymentStatus == 'failed') {
                      tileColor = Colors.red.withOpacity(0.1);
                    } else {
                      tileColor = Colors.yellow.withOpacity(0.1);
                    }

                    return Card(
                      color: tileColor,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: car['image_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  car['image_url'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.directions_car),
                        title: Text(car['name'] ?? 'Неизвестная машина'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'С ${booking['start_time'].toString().substring(0, 16).replaceAll('T', ' ')}\n'
                              'По ${booking['end_time'].toString().substring(0, 16).replaceAll('T', ' ')}',
                            ),
                            const SizedBox(height: 4),
                            Text('💰 Сумма: ${total.toStringAsFixed(2)} ₽'),
                            if (paymentStatus == 'failed' && unpaidAmount > 0) ...[
                              Text(
                                '🔻 Осталось оплатить: ${unpaidAmount.toStringAsFixed(2)} ₽',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '❗ Оплата не прошла',
                                style: TextStyle(
                                  color: Colors.red[900],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            if (paymentStatus == 'success')
                              const Text(
                                '✅ Оплачено',
                                style: TextStyle(color: Colors.green),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: (paymentStatus == 'failed' && unpaidAmount > 0)
                            ? ElevatedButton(
                                onPressed: () => _payDebt(booking['id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Оплатить'),
                              )
                            : null,
                        onTap: () => _showCarDetails(car),
                      ),
                    );
                  },
                ),
    );
  }
}
