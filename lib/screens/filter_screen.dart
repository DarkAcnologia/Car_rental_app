import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
class FilterScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;

  const FilterScreen({super.key, this.initialFilters});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  Set<String> selectedBrands = {};
  double minPrice = 0;
  double maxPrice = 100;
  double minFuelLevel = 0;
  bool childSeatOnly = false;

  List<String> allBrands = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    final filters = widget.initialFilters ?? {};
    selectedBrands = Set<String>.from(filters['brands'] ?? []);
    minPrice = filters['minPrice'] ?? 0;
    maxPrice = filters['maxPrice'] ?? 100;
    minFuelLevel = filters['minFuelLevel'] ?? 0;
    childSeatOnly = filters['childSeatOnly'] ?? false;
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    try {
      final res = await Supabase.instance.client
          .from('cars')
          .select('brand');

      final brands = res
          .map<String?>((e) => e['brand'] as String?)
          .where((b) => b != null && b.trim().isNotEmpty)
          .toSet()
          .cast<String>()
          .toList()
        ..sort();

      setState(() {
        allBrands = brands;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки брендов: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Фильтры автомобилей')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  const Text('Марки', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...allBrands.map((brand) => CheckboxListTile(
                        value: selectedBrands.contains(brand),
                        title: Text(brand),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selectedBrands.add(brand);
                            } else {
                              selectedBrands.remove(brand);
                            }
                          });
                        },
                      )),
                  const SizedBox(height: 16),
                  Text('Цена: от ${minPrice.toInt()} до ${maxPrice.toInt()} ₽'),
                  RangeSlider(
                    values: RangeValues(minPrice, maxPrice),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    labels: RangeLabels('${minPrice.toInt()}', '${maxPrice.toInt()}'),
                    onChanged: (values) => setState(() {
                      minPrice = values.start;
                      maxPrice = values.end;
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text('Мин. уровень топлива: ${minFuelLevel.toInt()}%'),
                  Slider(
                    value: minFuelLevel,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${minFuelLevel.toInt()}%',
                    onChanged: (value) => setState(() => minFuelLevel = value),
                  ),
                  SwitchListTile(
                    title: const Text('Только с детским креслом'),
                    value: childSeatOnly,
                    onChanged: (value) => setState(() => childSeatOnly = value),
                  ),
                  const SizedBox(height: 24),
ElevatedButton(
  onPressed: () {
    final filters = <String, dynamic>{};

    if (selectedBrands.isNotEmpty) {
      filters['brands'] = selectedBrands.toList();
    }

    if (minPrice > 0 || maxPrice < 100) {
      filters['minPrice'] = minPrice;
      filters['maxPrice'] = maxPrice;
    }

    if (minFuelLevel > 0) {
      filters['minFuelLevel'] = minFuelLevel;
    }

    if (childSeatOnly) {
      filters['childSeatOnly'] = true;
    }

    context.pop(filters); 
  },
  child: const Text('Применить фильтры'),
),


                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedBrands.clear();
                        minPrice = 0;
                        maxPrice = 100;
                        minFuelLevel = 0;
                        childSeatOnly = false;
                      });
                    },
                    child: const Text('Сбросить фильтры'),
                  )
                ],
              ),
            ),
    );
  }
}
