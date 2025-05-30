import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:car_rental_app/state/trip_state.dart';
import 'filter_screen.dart';
import 'menu_screen.dart';
import 'package:go_router/go_router.dart';
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
    // Бренды
    if (activeFilters['brands'] != null &&
        (activeFilters['brands'] as List).isNotEmpty &&
        !(activeFilters['brands'] as List).contains(car['brand'])) {
      return false;
    }

    // Цена
    if (activeFilters['minPrice'] != null &&
        activeFilters['maxPrice'] != null) {
      final price = car['price_per_minute'] ?? 0;
      if (price < activeFilters['minPrice'] ||
          price > activeFilters['maxPrice']) {
        return false;
      }
    }

    // Топливо
    if (activeFilters['minFuelLevel'] != null &&
        activeFilters['minFuelLevel'] > 0) {
      final fuel = car['fuel_level'] ?? 0;
      if (fuel < activeFilters['minFuelLevel']) {
        return false;
      }
    }

    // Детское кресло
    if (activeFilters['childSeatOnly'] == true &&
        car['has_child_seat'] != true) {
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
    final response = await Supabase.instance.client
        .from('cars')
        .select();

    if (mounted) {
      setState(() {
        cars = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Text(
                  _buildFilterSummary(),
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

Positioned.fill(
          child:YandexMap(
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
    bottom: 20,
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
          color: trip.isPaused ? Colors.orange[100] : Colors.white,
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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('⏱ $minutes:$seconds', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        Text('💰 ${trip.totalPrice.toStringAsFixed(2)} ₽', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(trip.isPaused ? Icons.play_arrow : Icons.pause),
                      onPressed: _togglePause,
                      color: trip.isPaused ? Colors.green : Colors.black87,
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
                    Text('🚀 $speed км/ч', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Text(isEngineOn ? '🟢 Двигатель' : '🔴 Двигатель'),
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
      return FloatingActionButton(
        heroTag: icon.toString(),
        mini: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        onPressed: onPressed,
        child: Icon(icon),
      );
    }

  void _showCarBottomSheet(BuildContext context, Map<String, dynamic> car) {
    _bottomSheetTimer?.cancel();

    // Безопасное закрытие, если уже открыт другой bottom sheet
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
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                              color: Colors.grey[300],
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
                        Text(car['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Описание: ${car['description'] ?? '—'}'),
                        Text('Цена за минуту: ${car['price_per_minute']} ₽'),
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
          setState(() {
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
          setState(() {
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

    setState(() {
      _bookedCar = null;
      _bookingEndTime = null;
    });
  }


void _stopTrip() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || trip.activeCar == null) return;

  final now = DateTime.now().toUtc();

  await Supabase.instance.client.from('bookings').update({
    'status': 'finished',
    'total_price': trip.totalPrice,
    'end_time': now.toIso8601String(),
  }).eq('car_id', trip.activeCar!['id'])
    .eq('user_id', user.id)
    .eq('status', 'active');

  Duration duration = Duration.zero;
  if (trip.startTime != null) {
    duration = now.difference(trip.startTime!.toUtc());
    if (duration.isNegative) {
      duration = Duration.zero; // на всякий случай, если время съехало
    }
  }

  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  final summary = '''
🕒 Длительность: $minutes:$seconds
💰 Итоговая сумма: ${trip.totalPrice.toStringAsFixed(2)} ₽
🚗 Статус: Завершено
''';

  if (context.mounted) {
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


  setState(() {
    trip.isPaused = !trip.isPaused;
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

void _billIfNeeded() async {
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