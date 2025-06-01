import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:car_rental_app/state/trip_state.dart';
import 'filter_screen.dart';
import 'shared_payment_screen.dart';
import 'contributor_input_screen.dart';
import 'menu_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
class MapScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;
  const MapScreen({super.key, this.initialFilters});


  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late YandexMapController mapController;
  PlacemarkMapObject? userPlacemark;
  Point? userPoint;
  bool trafficEnabled = false;
  List<Map<String, dynamic>> cars = [];
  Map<String, dynamic> activeFilters = {};
  Map<String, dynamic>? selectedCar;

  Map<String, dynamic>? _bookedCar;
  DateTime? _bookingEndTime;
  Timer? _bookingTimer;
  Timer? _bottomSheetTimer;

  final trip = TripState();
  Timer? _tripOverlayTimer;

  @override
  void initState() {
    super.initState();
    activeFilters = widget.initialFilters ?? {};
    _fetchCars();
  }

  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> cars) {
    return cars.where((car) {
      if (activeFilters['brands'] != null && (activeFilters['brands'] as List).isNotEmpty && !(activeFilters['brands'] as List).contains(car['brand'])) {
        return false;
      }
      if (activeFilters['minPrice'] != null && activeFilters['maxPrice'] != null) {
        final price = car['price_per_minute'] ?? 0;
        if (price < activeFilters['minPrice'] || price > activeFilters['maxPrice']) {
          return false;
        }
      }
      if (activeFilters['minFuelLevel'] != null && activeFilters['minFuelLevel'] > 0) {
        final fuel = car['fuel_level'] ?? 0;
        if (fuel < activeFilters['minFuelLevel']) {
          return false;
        }
      }
      if (activeFilters['childSeatOnly'] == true && car['has_child_seat'] != true) {
        return false;
      }
      return true;
    }).toList();
  }

  String _buildFilterSummary() {
    List<String> parts = [];
    if (activeFilters['brands'] != null && (activeFilters['brands'] as List).isNotEmpty) {
      final brands = (activeFilters['brands'] as List).join(', ');
      parts.add("Марки: $brands");
    }
    if (activeFilters['minPrice'] != null && activeFilters['maxPrice'] != null) {
      final min = (activeFilters['minPrice'] as num?)?.toInt();
      final max = (activeFilters['maxPrice'] as num?)?.toInt();
      if (min != null && max != null) {
        parts.add("Цена: $min–$max₽");
      }
    }
    if (activeFilters['minFuelLevel'] != null) {
      final fuel = (activeFilters['minFuelLevel'] as num?)?.toInt();
      if (fuel != null) {
        parts.add("Топливо > $fuel%");
      }
    }
    if (activeFilters['childSeatOnly'] == true) {
      parts.add("Детское кресло");
    }
    return parts.join(' • ');
  }

  Future<void> _fetchCars() async {
    final response = await Supabase.instance.client.from('cars').select();
    if (mounted) {
      setState(() {
        cars = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          if (activeFilters.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Text(
                  _buildFilterSummary(),
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          Positioned.fill(
            child: YandexMap(
              onMapCreated: (controller) async {
                mapController = controller;
                await _checkLocationAndInit();
              },
              mapObjects: [
                if (userPlacemark != null) userPlacemark!,
...applyFilters(cars).map((car) {
  final lat = (car['latitude'] as num?)?.toDouble();
  final lng = (car['longitude'] as num?)?.toDouble();
  if (lat == null || lng == null) return null;

  return PlacemarkMapObject(
    mapId: MapObjectId(car['id']),
    point: Point(latitude: lat, longitude: lng),
    icon: PlacemarkIcon.single(
      PlacemarkIconStyle(
        image: BitmapDescriptor.fromAssetImage('assets/car.png'),
        scale: 2,
      ),
    ),
    onTap: (_, __) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final theme = Theme.of(context);

      // 1. Проверка верификации
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final profile = response as Map<String, dynamic>?;

      if (profile == null || profile['is_verified'] != true) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              titleTextStyle: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface),
              contentTextStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
              title: const Text('Аккаунт не верифицирован'),
              content: const Text('Ожидайте подтверждения ваших данных администрацией.'),
              actions: [
                TextButton(
                  child: const Text('ОК'),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
          );
        }
        return;
      }

      // 2. Проверка задолженности
      final unpaidRes = await Supabase.instance.client
          .from('bookings')
          .select()
          .eq('user_id', user.id)
          .eq('payment_status', 'failed');

      if (unpaidRes != null && unpaidRes is List && unpaidRes.isNotEmpty) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              titleTextStyle: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface),
              contentTextStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
              title: const Text('Неоплаченная поездка'),
              content: const Text('У вас есть поездка с неуспешной оплатой. Погасите задолженность перед новой арендой.Это можно сделать в истории бронированний'),
              actions: [
                TextButton(
                  child: const Text('ОК'),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
          );
        }
        return;
      }

      // 3. Всё в порядке — показываем машину
      setState(() => selectedCar = car);
      _showCarBottomSheet(context, car);
    },
  );
}).whereType<PlacemarkMapObject>(),

              ],
            ),
          ),
          if (trip.activeCar != null) _buildTripOverlay(),
          Positioned(
            right: 10,
            bottom: 160,
            child: Column(
              children: [
                _buildButton(Icons.my_location, _moveToUserLocation),
                const SizedBox(height: 12),
                _buildButton(Icons.explore, _resetNorthOrientation),
                const SizedBox(height: 12),
                _buildButton(
                  trafficEnabled ? Icons.traffic : Icons.traffic_outlined,
                  _toggleTraffic,
                ),
                const SizedBox(height: 12),
                _buildButton(Icons.filter_list, () async {
                  final result = await context.push<Map<String, dynamic>>(
                    '/filters',
                    extra: activeFilters,
                  );
                  if (result != null) {
                    debugPrint('Полученные фильтры: $result');
                    setState(() {
                      activeFilters = result;
                    });
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Часть нового виджета внутри _buildTripOverlay
Widget _buildTripOverlay() {
  _tripOverlayTimer?.cancel();
  _tripOverlayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() {});
  });

  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  final elapsed = trip.startTime != null
      ? DateTime.now().difference(trip.startTime!)
      : Duration.zero;

  final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

  final car = trip.activeCar;
  final fuelLevel = (car?['fuel_level'] as num?)?.toDouble() ?? 0;
  final speed = car?['speed']?.toString() ?? '0';
  final isEngineOn = car?['is_engine_on'] == true;
  final isLocked = car?['is_locked'] == true;

  return Positioned(
    left: 12,
    right: 12,
    bottom: 60,
    child: GestureDetector(
      onTap: () {
        if (trip.activeCar != null) {
          setState(() => selectedCar = trip.activeCar);
          _showCarBottomSheet(context, trip.activeCar!);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: trip.isPaused ? Colors.orange.withOpacity(1.0) : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.isPaused ? '⏸ Поездка на паузе' : '🟢 Поездка активна',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('⏱ $minutes:$seconds', style: theme.textTheme.bodyLarge),
                        const SizedBox(width: 12),
                        Text('💰 ${trip.totalPrice.toStringAsFixed(2)} ₽', style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(trip.isPaused ? Icons.play_arrow : Icons.pause),
                      onPressed: _togglePause,
                      color: trip.isPaused ? Colors.green : colorScheme.onSurface,
                      tooltip: trip.isPaused ? 'Продолжить' : 'Пауза',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed: _stopTrip,
                      color: Colors.red,
                      tooltip: 'Стоп',
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFuelIndicator(fuelLevel),
                Column(
                  children: [
                    Text('🚀 $speed км/ч', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                    Text(isEngineOn ? '🟢 Двигатель' : '🔴 Двигатель', style: theme.textTheme.bodyMedium),
                  ],
                ),
                IconButton(
                  icon: Icon(isLocked ? Icons.lock_open : Icons.lock),
                  onPressed: _toggleLock,
                  color: isLocked ? Colors.orange : Colors.green,
                ),
                IconButton(
                  icon: const Icon(Icons.power_settings_new),
                  onPressed: _toggleEngine,
                  color: isEngineOn ? Colors.red : Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}


Widget _buildFuelIndicator(double level) {
  int filledSegments = (level / 25).ceil().clamp(0, 4);
  List<Color> colors = [Colors.grey[300]!, Colors.grey[300]!, Colors.grey[300]!, Colors.grey[300]!];

  for (int i = 0; i < filledSegments; i++) {
    colors[i] = level > 75 ? Colors.green : level > 50 ? Colors.yellow : level > 25 ? Colors.orange : Colors.red;
  }

  return Column(
    children: [
      const Text('⛽ Топливо'),
      Row(
        children: List.generate(4, (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 10,
          height: 20,
          color: colors[index],
        )),
      ),
    ],
  );
}

Future<void> _toggleLock() async {
  final car = trip.activeCar;
  if (car == null) return;
  final newState = !(car['is_locked'] as bool? ?? false);
  await Supabase.instance.client
      .from('cars')
      .update({'is_locked': newState})
      .eq('id', car['id']);
  setState(() => car['is_locked'] = newState);
}

Future<void> _toggleEngine() async {
  final car = trip.activeCar;
  if (car == null) return;
  final newState = !(car['is_engine_on'] as bool? ?? false);
  await Supabase.instance.client
      .from('cars')
      .update({'is_engine_on': newState})
      .eq('id', car['id']);
  setState(() => car['is_engine_on'] = newState);
}

  Widget _buildButton(IconData icon, VoidCallback onPressed) {
    final theme = Theme.of(context);
    return FloatingActionButton(
      heroTag: icon.toString(),
      mini: true,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }

  void _showCarBottomSheet(BuildContext context, Map<String, dynamic> car) {
  _bottomSheetTimer?.cancel();

  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          _bottomSheetTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (_bookingEndTime != null && mounted) {
              setModalState(() {});
            }
          });

          final isBooked = _bookedCar?['id'] == car['id'];
          final isActive = trip.activeCar?['id'] == car['id'];

          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            maxChildSize: 0.8,
            builder: (_, controller) {
              final theme = Theme.of(context);
              final cardColor = theme.colorScheme.surface;
              final textColor = theme.colorScheme.onSurface;

              return Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(16),
                child: ListView(
                  controller: controller,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (car['image_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(car['image_url'], height: 160, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 12),
                    Text(car['name'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                    Text('Описание: ${car['description'] ?? '—'}', style: TextStyle(color: textColor)),
                    Text('Цена за минуту: ${car['price_per_minute']} ₽', style: TextStyle(color: textColor)),
                    if (isBooked && _bookingEndTime != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('⏳ Осталось: ${_formattedTimeLeft()}', style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 16),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    _actionButton(Icons.volume_up, 'Бип-бип', () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚗 Бип-бип!')),
      );
    }),

    // 🔐 Показываем "Открыть/Закрыть" только если двигатель заведен
    if (car['is_engine_on'] == true)
_actionButton(
  car['is_locked'] == true ? Icons.lock_open : Icons.lock,
  car['is_locked'] == true ? 'Открыть' : 'Закрыть',
  () async {
    final newLockState = !(car['is_locked'] as bool);
    await Supabase.instance.client
        .from('cars')
        .update({'is_locked': newLockState})
        .eq('id', car['id']);

    setModalState(() {
      car['is_locked'] = newLockState;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(newLockState ? '🚪 Двери открыты' : '🔒 Двери закрыты')),
    );
  },
  color: car['is_locked'] == true ? Colors.orange : Colors.green,
  textColor: Colors.white,
),


    if (!isActive)
      _actionButton(Icons.play_arrow, 'Пуск', () {
        Navigator.of(context).pop();
        _startTrip(car);
      }),

    if (!isActive)
      _actionButton(Icons.lock_clock, isBooked ? 'Отмена' : 'Бронь', () {
        isBooked ? _cancelBooking() : _bookCar(car);
      }, color: isBooked ? Colors.grey : Colors.orange, textColor: Colors.white),

    if (isActive)
    _actionButton(
  Icons.power_settings_new,
  car['is_engine_on'] == true ? 'Заглушить' : 'Завести',
  () async {
    final newEngineState = !(car['is_engine_on'] as bool? ?? false);
    await Supabase.instance.client
        .from('cars')
        .update({'is_engine_on': newEngineState})
        .eq('id', car['id']);

    setModalState(() {
      car['is_engine_on'] = newEngineState;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newEngineState ? '🚘 Двигатель заведен' : '🛑 Двигатель заглушен',
        ),
      ),
    );
  },
  color: car['is_engine_on'] == true ? Colors.red : Colors.green,
  textColor: Colors.white,
),
  ],
),

const SizedBox(height: 12),

// 🧠 Всегда показываем статус двигателя и топливо
Text(
  car['is_engine_on'] == true
      ? '🟢 Двигатель работает'
      : '🔴 Двигатель выключен',
  style: const TextStyle(fontWeight: FontWeight.w600),
),
const SizedBox(height: 8),

Text('⛽ Уровень топлива: ${car['fuel_level'] ?? '—'} %'),

// 🚀 Скорость только при заведённом двигателе
if (car['is_engine_on'] == true)
  Text('🚀 Скорость: ${car['speed'] ?? '0'} км/ч'),


                      ],
                    ),
                  );
                },
              );
            },
          );
        },
    ).whenComplete(() {
      _bottomSheetTimer?.cancel();
      setState(() => selectedCar = null);
    });
    }

Future<void> _showNotVerifiedDialog(BuildContext context) async {
  final theme = Theme.of(context);
  final bgColor = theme.colorScheme.surface;
  final txtColor = theme.colorScheme.onSurface;

  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: bgColor,
      titleTextStyle: TextStyle(color: txtColor, fontSize: 20, fontWeight: FontWeight.bold),
      contentTextStyle: TextStyle(color: txtColor),
      title: const Text('Аккаунт не верифицирован'),
      content: const Text('Ожидайте подтверждения ваших данных администрацией.'),
      actions: [
        TextButton(
          child: const Text('ОК'),
          onPressed: () => Navigator.of(context).pop(),
        )
      ],
    ),
  );
}

    Widget _actionButton(IconData icon, String text, VoidCallback onPressed, {Color? color, Color? textColor}) {
      return Expanded(
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.grey[200],
            foregroundColor: textColor ?? Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

Future<void> _bookCar(Map<String, dynamic> car) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

final response = await Supabase.instance.client
    .from('profiles')
    .select()
    .eq('id', user.id)
    .maybeSingle();

final profile = response as Map<String, dynamic>?;

if (profile == null || profile['is_verified'] != true) {
  if (context.mounted) {
showDialog(
  context: context,
  builder: (_) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface,
    title: Text(
      'Аккаунт не верифицирован',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    ),
    content: Text(
      'Ожидайте подтверждения ваших данных администрацией.',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    ),
    actions: [
      TextButton(
        child: const Text('ОК'),
        onPressed: () => Navigator.of(context).pop(),
      )
    ],
  ),
);
  }
  return;
}




      final now = DateTime.now();
      final end = now.add(const Duration(minutes: 20));

await Supabase.instance.client.from('bookings').insert({
  'user_id': user.id,
  'car_id': car['id'],
  'start_time': now.toIso8601String(),
  'end_time': end.toIso8601String(),
  'status': 'active',
  'is_paused': false,
});


      setState(() {
        _bookedCar = car;
        _bookingEndTime = end;
      });

      _bookingTimer?.cancel();
      _bookingTimer = Timer(const Duration(minutes: 20), () => _cancelBooking());
    }

  void _cancelBooking() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _bookedCar == null) return;

    final now = DateTime.now().toUtc();

    await Supabase.instance.client
        .from('bookings')
        .update({
          'end_time': now.toIso8601String(),
          'status': 'cancelled',
        })
        .eq('car_id', _bookedCar!['id'])
        .eq('user_id', user.id)
        .eq('status', 'active');

    setState(() {
      _bookedCar = null;
      _bookingEndTime = null;
    });

    _fetchCars();
  }

  void _startTrip(Map<String, dynamic> car) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now().toUtc();

    // Пробуем получить активную бронь
    final bookingRaw = await Supabase.instance.client
        .from('bookings')
        .select()
        .eq('car_id', car['id'])
        .eq('user_id', user.id)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    Map<String, dynamic> booking;

    if (bookingRaw == null) {
      // Брони нет — создаем поездку с начальным временем
      final insertResponse = await Supabase.instance.client.from('bookings').insert({
        'user_id': user.id,
        'car_id': car['id'],
        'start_time': now.toIso8601String(),
        'end_time': now.toIso8601String(),
        'status': 'active',
        'is_paused': false,
        'total_price': 0.0,
        'last_billing_time': now.toIso8601String(),
      }).select().single();

      booking = insertResponse;
    } else {
      booking = bookingRaw as Map<String, dynamic>;
      // Обновим start_time и end_time до текущего момента, т.к. поездка началась
      await Supabase.instance.client
          .from('bookings')
          .update({
            'start_time': now.toIso8601String(),
            'end_time': now.toIso8601String(),
          })
          .eq('id', booking['id']);
    }

    // Обновляем локальное состояние
    trip
      ..activeCar = car
      ..startTime = now.toLocal()
      ..isPaused = false
      ..totalPrice = 0.0;

    // Запуск биллинга
    trip.priceTimer?.cancel();
    trip.priceTimer = Timer.periodic(const Duration(seconds: 10), (_) => _billIfNeeded());
    
    await _billInitialMinute(); // 💸 Мгновенное первое начисление

    setState(() {
      _bookedCar = null;
      _bookingEndTime = null;
    });
  }


void _stopTrip() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || trip.activeCar == null) return;

  final now = DateTime.now().toUtc();

  final booking = await Supabase.instance.client
      .from('bookings')
      .select()
      .eq('car_id', trip.activeCar!['id'])
      .eq('user_id', user.id)
      .eq('status', 'active')
      .maybeSingle();

  if (booking != null) {
    await Supabase.instance.client
        .from('bookings')
        .update({
          'end_time': now.toIso8601String(),
          'status': 'finished',
        })
        .eq('id', booking['id']);
  }

  String? paymentMode;
  if (trip.totalPrice > 0 && context.mounted) {
    paymentMode = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Как вы хотите оплатить?'),
        content: const Text('Выберите способ оплаты:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'solo'),
            child: const Text('Оплатить сам'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'shared'),
            child: const Text('Разделить счёт'),
          ),
        ],
      ),
    );
  }

  final bookingResponse = await Supabase.instance.client
      .from('bookings')
      .select('id')
      .eq('car_id', trip.activeCar!['id'])
      .eq('user_id', user.id)
      .eq('status', 'finished')
      .order('end_time', ascending: false)
      .limit(1)
      .single();

  final bookingId = bookingResponse['id'];

  if (trip.totalPrice > 0 && paymentMode == 'solo') {
    try {
      final paymentResponse = await http.post(
        Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.id,
          'booking_id': bookingId,
        }),
      );

      final result = jsonDecode(paymentResponse.body);
      if (paymentResponse.statusCode == 200 && result['success'] == true) {
        debugPrint('💸 Оплата прошла успешно!');
      } else {
        debugPrint('❌ Ошибка при оплате: ${result['error']}');
      }
    } catch (e) {
      debugPrint('❌ Сбой оплаты: $e');
    }
  }

  if (trip.totalPrice > 0 && paymentMode == 'shared') {
   // Открываем экран ввода участников
final contributors = await Navigator.push<List<Map<String, dynamic>>>(
  context,
  MaterialPageRoute(
    builder: (_) => ContributorInputScreen(
      totalAmount: trip.totalPrice,
      bookingId: bookingId,
    ),
  ),
);

if (contributors == null || contributors.isEmpty) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Вы не добавили ни одного участника')),
    );
  }
  return;
}

// Показываем индикатор загрузки
if (context.mounted) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );
}

final paymentLinks = <Map<String, dynamic>>[];

for (final c in contributors) {
  final response = await Supabase.instance.client
      .from('split_payments')
      .insert({
        'booking_id': bookingId,
        'contributor_name': c['name'],
        'amount': c['amount'],
      })
      .select()
      .single();

  final splitId = response['id'];

  final linkRes = await http.post(
    Uri.parse('https://jekylcxrzokwdjlknxjz.functions.supabase.co/create-split-payment'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'split_payment_id': splitId,
    }),
  );

  final linkData = jsonDecode(linkRes.body);
  if (linkRes.statusCode == 200 && linkData['url'] != null) {
    paymentLinks.add({
      'name': c['name'],
      'amount': c['amount'],
      'link': linkData['url'],
    });
  } else {
    debugPrint('❌ Ошибка при создании ссылки для ${c['name']}: ${linkData['error']}');
  }
}

// Закрываем индикатор
if (context.mounted) Navigator.pop(context);

// Открываем SharedPaymentScreen
if (context.mounted) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SharedPaymentScreen(
        bookingId: bookingId,
        contributors: paymentLinks,
      ),
    ),
  );
}

  }

  Duration duration = Duration.zero;
  if (trip.startTime != null) {
    duration = now.difference(trip.startTime!.toUtc());
    if (duration.isNegative) duration = Duration.zero;
  }

  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  final summary = '''
🕒 Длительность: $minutes:$seconds
💰 Итоговая сумма: ${trip.totalPrice.toStringAsFixed(2)} ₽
🚗 Статус: Завершено
''';

  if (context.mounted && paymentMode != 'shared') {
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Поездка завершена'),
      content: Text(summary),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ОК'),
        )
      ],
    ),
  );
}


  setState(() {
    trip
      ..activeCar = null
      ..totalPrice = 0.0
      ..startTime = null
      ..isPaused = false;
    trip.priceTimer?.cancel();
  });

  _fetchCars();
}


void _togglePause() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || trip.activeCar == null) return;

  final isPausing = !trip.isPaused;

  if (isPausing) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пауза поездки'),
        content: const Text('Во время паузы будет списываться 50% от стоимости аренды в минуту. Продолжить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Да'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
  }

  setState(() {
    trip.isPaused = isPausing;
  });

  await Supabase.instance.client
      .from('bookings')
      .update({'is_paused': trip.isPaused})
      .eq('car_id', trip.activeCar!['id'])
      .eq('user_id', user.id)
      .eq('status', 'active');

  if (!mounted) return;

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        trip.isPaused
            ? '⏸ Поездка поставлена на паузу. Списывается 50% стоимости.'
            : '▶️ Поездка продолжена.',
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

Future<void> _billInitialMinute() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || trip.activeCar == null) return;

  final now = DateTime.now().toUtc();

  final pricePerMin = (trip.activeCar!['price_per_minute'] as num).toDouble();
  final cost = pricePerMin;

  setState(() {
    trip.totalPrice += cost;
  });

  await Supabase.instance.client
      .from('bookings')
      .update({
        'last_billing_time': now.toIso8601String(),
        'total_price': trip.totalPrice,
      })
      .eq('car_id', trip.activeCar!['id'])
      .eq('user_id', user.id)
      .eq('status', 'active');
}

Future<void> _billIfNeeded() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || trip.activeCar == null) return;

  final booking = await Supabase.instance.client
      .from('bookings')
      .select()
      .eq('car_id', trip.activeCar!['id'])
      .eq('user_id', user.id)
      .eq('status', 'active')
      .maybeSingle();

  if (booking == null) return;

  final lastBillingStr = booking['last_billing_time'];
  final lastBillingTime = lastBillingStr != null
      ? DateTime.parse(lastBillingStr).toUtc()
      : null;

  final now = DateTime.now().toUtc();

  if (lastBillingTime == null ||
      now.difference(lastBillingTime).inMinutes >= 1) {
    final pricePerMin = (trip.activeCar!['price_per_minute'] as num).toDouble();
    final cost = (booking['is_paused'] == true)
        ? pricePerMin / 2
        : pricePerMin;

    setState(() {
      trip.totalPrice += cost;
    });

    await Supabase.instance.client
        .from('bookings')
        .update({
          'last_billing_time': now.toIso8601String(),
          'total_price': trip.totalPrice,
        })
        .eq('car_id', trip.activeCar!['id'])
        .eq('user_id', user.id)
        .eq('status', 'active');
  }
}




    String _formattedTimeLeft() {
      final diff = _bookingEndTime!.difference(DateTime.now());
      final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    Future<void> _checkLocationAndInit() async {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Геолокация отключена')));
        return;
      }

      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Разрешение на геолокацию отклонено')));
        }
        return;
      }

      await _updateUserLocation();
    }

    Future<void> _updateUserLocation() async {
      try {
        final position = await Geolocator.getCurrentPosition();
        userPoint = Point(latitude: position.latitude, longitude: position.longitude);

        setState(() {
          userPlacemark = PlacemarkMapObject(
            mapId: const MapObjectId('user_location'),
            point: userPoint!,
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(
                image: BitmapDescriptor.fromAssetImage('assets/user.png'),
                scale: 2,
              ),
            ),
          );
        });

        await mapController.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: userPoint!, zoom: 15),
          ),
        );
      } catch (e) {
        debugPrint('Ошибка геолокации: $e');
      }
    }

    Future<void> _moveToUserLocation() async {
      if (userPoint == null) await _updateUserLocation();
      if (userPoint != null) {
        await mapController.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: userPoint!, zoom: 15),
          ),
        );
      }
    }

    Future<void> _resetNorthOrientation() async {
      final pos = await mapController.getCameraPosition();
      await mapController.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: pos.target,
            zoom: pos.zoom,
            tilt: pos.tilt,
            azimuth: 0,
          ),
        ),
      );
    }

    Future<void> _toggleTraffic() async {
      trafficEnabled = !trafficEnabled;
      await mapController.toggleTrafficLayer(visible: trafficEnabled);
      setState(() {});
    }
    

  }