import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_reveal.dart';
import 'journal_models.dart';

enum JournalStatus { all, running, closed }

class JournalFilter {
  JournalStatus status = JournalStatus.all;
  String? symbol;
  String? management;

  void reset() {
    status = JournalStatus.all;
    symbol = null;
    management = null;
  }

  List<TradeEntry> apply(Iterable<TradeEntry> trades) => trades.where((trade) {
    return (status == JournalStatus.all ||
            (status == JournalStatus.running
                ? trade.isRunning
                : !trade.isRunning)) &&
        (symbol == null || trade.symbol == symbol) &&
        (management == null || trade.management == management);
  }).toList();
}

class JournalFilterBar extends StatelessWidget {
  const JournalFilterBar({
    super.key,
    required this.filter,
    required this.trades,
    required this.onChanged,
  });
  final JournalFilter filter;
  final List<TradeEntry> trades;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final symbols = trades.map((trade) => trade.symbol).toSet().toList()
      ..sort();
    return Column(
      children: [
        AnimatedSegmentedControl(
          labels: const ['Tất cả', 'Đang chạy', 'Đã đóng'],
          selectedIndex: filter.status.index,
          selectedColor: context.appStatusColors.primary,
          onChanged: (index) {
            filter.status = JournalStatus.values[index];
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('symbol-${filter.symbol}-${symbols.join()}'),
                initialValue: symbols.contains(filter.symbol)
                    ? filter.symbol
                    : '',
                decoration: const InputDecoration(
                  labelText: 'Tài sản',
                  isDense: true,
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Tất cả tài sản'),
                  ),
                  ...symbols.map(
                    (symbol) =>
                        DropdownMenuItem(value: symbol, child: Text(symbol)),
                  ),
                ],
                onChanged: (value) {
                  filter.symbol = value == '' ? null : value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('management-${filter.management}'),
                initialValue: filter.management ?? '',
                decoration: const InputDecoration(
                  labelText: 'Quản lý lệnh',
                  isDense: true,
                ),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: '', child: Text('Tất cả')),
                  DropdownMenuItem(
                    value: 'Xử lý lệnh',
                    child: Text('Xử lý lệnh'),
                  ),
                  DropdownMenuItem(
                    value: 'Set and forget',
                    child: Text('Set and forget'),
                  ),
                ],
                onChanged: (value) {
                  filter.management = value == '' ? null : value;
                  onChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
