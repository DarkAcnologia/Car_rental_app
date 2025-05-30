import 'dart:async';

class TripState {
  static final TripState _instance = TripState._internal();
  factory TripState() => _instance;

  TripState._internal();

  Map<String, dynamic>? activeCar;
  DateTime? startTime;
  double totalPrice = 0.0;
  bool isPaused = false;
  Timer? priceTimer;

  void reset() {
    activeCar = null;
    startTime = null;
    totalPrice = 0.0;
    isPaused = false;
    priceTimer?.cancel();
    priceTimer = null;
  }
}
