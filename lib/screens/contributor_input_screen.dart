import 'package:flutter/material.dart';

class ContributorInputScreen extends StatefulWidget {
  final double totalAmount;
  final String bookingId;

  const ContributorInputScreen({
    super.key,
    required this.totalAmount,
    required this.bookingId,
  });

  @override
  State<ContributorInputScreen> createState() => _ContributorInputScreenState();
}

class _ContributorInputScreenState extends State<ContributorInputScreen> {
  final List<Map<String, dynamic>> _contributors = [];
  final _formKey = GlobalKey<FormState>();

  void _addContributor() {
    setState(() {
      _contributors.add({
        'name': '',
        'amount': 0.0,
        'controller': TextEditingController(),
      });
    });
  }

  void _removeContributor(int index) {
    setState(() {
      _contributors[index]['controller'].dispose();
      _contributors.removeAt(index);
    });
  }

  void _splitEvenly() {
    if (_contributors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте участников')),
      );
      return;
    }

    final splitAmount = widget.totalAmount / _contributors.length;
    setState(() {
      for (var c in _contributors) {
        c['amount'] = double.parse(splitAmount.toStringAsFixed(2));
        c['controller'].text = c['amount'].toString();
      }
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final total = _contributors.fold<double>(
        0.0,
        (sum, c) => sum + (c['amount'] as double),
      );

      if ((total - widget.totalAmount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сумма участников не совпадает с общей суммой'),
          ),
        );
        return;
      }

      // Удаляем контроллеры перед возвратом
      for (var c in _contributors) {
        c.remove('controller');
      }

      Navigator.pop(context, _contributors);
    }
  }

  @override
  void dispose() {
    for (final c in _contributors) {
      c['controller'].dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _addContributor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Разделить счёт')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'Итоговая сумма: ${widget.totalAmount.toStringAsFixed(2)} ₽',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _contributors.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            TextFormField(
                              decoration: const InputDecoration(labelText: 'Имя участника'),
                              onSaved: (value) =>
                                  _contributors[index]['name'] = value?.trim() ?? '',
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? 'Введите имя'
                                  : null,
                            ),
                            TextFormField(
                              controller: _contributors[index]['controller'],
                              decoration: const InputDecoration(labelText: 'Сумма, ₽'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              onSaved: (value) => _contributors[index]['amount'] =
                                  double.tryParse(value ?? '0') ?? 0.0,
                              validator: (value) => (value == null ||
                                      double.tryParse(value) == null ||
                                      double.parse(value) <= 0)
                                  ? 'Введите корректную сумму'
                                  : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeContributor(index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить участника'),
                      onPressed: _addContributor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.equalizer),
                      label: const Text('Разделить поровну'),
                      onPressed: _splitEvenly,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Продолжить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
