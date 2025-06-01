// lib/screens/instruction_screen.dart
import 'package:flutter/material.dart';

class InstructionScreen extends StatelessWidget {
  const InstructionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Инструкция')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              '🚗 Инструкция по использованию',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '📍 Карта\n- На главной карте отображаются доступные автомобили.\n'
              '- Нажмите на иконку автомобиля, чтобы открыть карточку с его данными.',
            ),
            const SizedBox(height: 12),
            const Text(
              '🟢 Бронирование и поездка\n'
              '- Кнопка "Бронь" — бронирует машину на 20 минут.\n'
              '- Кнопка "Пуск" — запускает поездку.\n'
              '- Во время поездки отображается стоимость и управление автомобилем.',
            ),
            const SizedBox(height: 12),
            const Text(
              '🛠️ Управление автомобилем (значки):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            _buildIconRow('🔓', 'Открыть двери — разблокировать машину'),
            _buildIconRow('🔒', 'Закрыть двери — заблокировать машину'),
            _buildIconRow('🟢', 'Завести двигатель — зелёный круг с полоской сверху'),
            _buildIconRow('🔴', 'Заглушить двигатель — красный круг с полоской сверху'),
            _buildIconRow('📢', 'Бип-бип — подать сигнал, чтобы найти авто'),
            _buildIconRow('⏸', 'Пауза — временно остановить аренду (оплата 50%)'),
            _buildIconRow('⏹', 'Стоп — завершить поездку полностью'),
            const SizedBox(height: 12),
            const Text(
              '💳 Оплата\n'
              '- Оплата списывается автоматически с вашей сохранённой карты.\n'
              '- Можно использовать совместную оплату — каждый платит свою часть.\n'
              '- При частичной оплате долг можно погасить в Истории бронирований.',
            ),
            const SizedBox(height: 12),
            const Text(
              '🎨 Темы\n'
              '- Перейдите в Меню → Темы, чтобы выбрать светлую, тёмную или авто тему.',
            ),
            const SizedBox(height: 12),
            const Text(
              'ℹ️ Дополнительно\n'
              '- Добавьте карту в разделе "Способ оплаты".\n'
              '- В случае вопросов или проблем — обратитесь в поддержку.',
            ),
           const Text(
  '📷 Камеры и безопасность\n'
  '- В автомобиле установлены камеры для обеспечения безопасности.\n'
  '- Водитель должен соответствовать предоставленным данным (фото лица и ВУ).\n'
  '- В случае несоответствия аккаунт может быть заблокирован.',
),
          ],
        ),
      ),
    );
  }

  Widget _buildIconRow(String icon, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }
}
