import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_reveal.dart';
import 'checkin_notification_service.dart';
import 'market_alerts_local_repository.dart';
import 'market_alerts_models.dart';

class MarketAlertsScreen extends StatefulWidget {
  const MarketAlertsScreen({super.key});

  @override
  State<MarketAlertsScreen> createState() => _MarketAlertsScreenState();
}

class _MarketAlertsScreenState extends State<MarketAlertsScreen> {
  final _repository = MarketAlertsLocalRepository();
  MarketAlertSettings _settings = const MarketAlertSettings();
  bool _loading = true;

  // Group assets by the market family users actually configure.
  static const _assetGroups = <String, List<String>>{
    'Coins (BTC, ETH...)': ['BTCUSDT', 'ETHUSDT'],
    'Vàng bạc': ['XAUUSD', 'XAGUSD'],
  };
  static const _frames = ['H4', 'Ngày', 'Tuần', 'Tháng'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
    await CheckinNotificationService.scheduleMarketAlerts(settings);
  }

  Future<void> _update(MarketAlertSettings next) async {
    setState(() => _settings = next);
    await _repository.save(next);
    await CheckinNotificationService.scheduleMarketAlerts(next);
  }

  void _toggleAsset(List<String> assetsInGroup, String frame, bool value) {
    final assets = {
      for (final entry in _settings.assetSettings.entries)
        entry.key: {...entry.value},
    };
    for (final asset in assetsInGroup) {
      assets.putIfAbsent(
        asset,
        () => {for (final frame in _frames) frame: false},
      );
      assets[asset]![frame] = value;
    }
    _update(_settings.copyWith(assetSettings: assets));
  }

  bool _assetEnabled(List<String> assetsInGroup) => assetsInGroup.any(
    (asset) =>
        _settings.assetSettings[asset]?.values.any((enabled) => enabled) ??
        false,
  );

  Map<String, bool> _groupSettings(List<String> assetsInGroup) => {
    for (final frame in _frames)
      frame: assetsInGroup.any(
        (asset) => _settings.assetSettings[asset]?[frame] ?? false,
      ),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Cảnh báo giờ thị trường'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                6,
                20,
                MediaQuery.viewPaddingOf(context).bottom + 32,
              ),
              children: [
                AnimatedReveal(
                  child: _HeroCard(
                    settings: _settings,
                    onChanged: (value) =>
                        _update(_settings.copyWith(enabled: value)),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedReveal(
                  delay: const Duration(milliseconds: 70),
                  child: _InfoBanner(enabled: _settings.enabled),
                ),
                const SizedBox(height: 24),
                const AnimatedReveal(
                  delay: Duration(milliseconds: 110),
                  child: _SectionHeading(title: 'Đóng cửa nến theo tài sản'),
                ),
                const SizedBox(height: 10),
                ..._assetGroups.entries.toList().asMap().entries.map(
                  (entry) => AnimatedReveal(
                    delay: Duration(milliseconds: 140 + entry.key * 80),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AssetCard(
                        title: entry.value.key,
                        assets: entry.value.value,
                        active: _settings.enabled &&
                            _assetEnabled(entry.value.value),
                        interactive: _settings.enabled,
                        settings: _groupSettings(entry.value.value),
                        onChanged: (frame, value) =>
                            _toggleAsset(entry.value.value, frame, value),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const AnimatedReveal(
                  delay: Duration(milliseconds: 270),
                  child: _SectionHeading(title: 'Phiên giao dịch'),
                ),
                const SizedBox(height: 10),
                AnimatedReveal(
                  delay: const Duration(milliseconds: 300),
                  child: _SessionCard(
                    value: _settings.usSession,
                    interactive: _settings.enabled,
                    onChanged: (value) =>
                        _update(_settings.copyWith(usSession: value)),
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedReveal(
                  delay: const Duration(milliseconds: 350),
                  child: Text(
                    'Các mốc giờ được tính theo múi giờ hiện tại của iPhone. Bạn có thể thay đổi từng cảnh báo bất cứ lúc nào.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.settings, required this.onChanged});
  final MarketAlertSettings settings;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 280),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: settings.enabled
            ? [context.appStatusColors.primary, context.appStatusColors.dark]
            : const [AppColors.muted, Color(0xFF4D6473)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color:
              (settings.enabled
                      ? context.appStatusColors.primary
                      : AppColors.ink)
                  .withValues(alpha: .16),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (settings.enabled ? AppColors.lime : Colors.white)
                .withValues(alpha: .9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            settings.enabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            color: settings.enabled
                ? context.appStatusColors.dark
                : AppColors.muted,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cảnh báo giờ thị trường',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Nhắc bạn trước các mốc quan trọng',
                style: TextStyle(color: Color(0xFFD7E7F0), fontSize: 11),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: settings.enabled,
          onChanged: onChanged,
          activeThumbColor: AppColors.lime,
          activeTrackColor: context.appStatusColors.dark,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.white24,
        ),
      ],
    ),
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: enabled
          ? AppColors.lime.withValues(alpha: .32)
          : AppColors.line.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 18,
          color: enabled ? context.appStatusColors.dark : AppColors.muted,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            enabled
                ? 'Thông báo cục bộ đang hoạt động trên thiết bị này.'
                : 'Tất cả cảnh báo đang tạm dừng.',
            style: TextStyle(
              color: enabled ? context.appStatusColors.dark : AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) =>
      Text(title, style: Theme.of(context).textTheme.titleLarge);
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.title,
    required this.assets,
    required this.active,
    required this.interactive,
    required this.settings,
    required this.onChanged,
  });
  final String title;
  final List<String> assets;
  final bool active;
  final bool interactive;
  final Map<String, bool> settings;
  final void Function(String frame, bool value) onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: assets.first == 'BTCUSDT'
                      ? const Color(0xFFFFF1D5)
                      : const Color(0xFFE3EEF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  assets.first == 'BTCUSDT'
                      ? Icons.currency_bitcoin_rounded
                      : Icons.monetization_on_outlined,
                  color: assets.first == 'BTCUSDT'
                      ? AppColors.gold
                      : context.appStatusColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  active ? 'Đang bật' : 'Đang tắt',
                  key: ValueKey(active),
                  style: TextStyle(
                    color: active
                        ? context.appStatusColors.primary
                        : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          ...['H4', 'Ngày', 'Tuần', 'Tháng'].map(
            (frame) => _AlertSwitchRow(
              title: 'Đóng cửa nến $frame',
              subtitle: switch (frame) {
                'H4' => 'Theo các mốc đóng nến trong ngày',
                'Ngày' => 'BTC 07/08h · Vàng 05/06h (GMT+7)',
                'Tháng' => 'Ngày cuối tháng 30/31 · theo giờ tài sản',
                'Tuần' => 'BTC 07/08h thứ 2 · Vàng 21/22h thứ 6',
                _ => 'Theo lịch thị trường',
              },
              value: settings[frame] ?? false,
              enabled: interactive,
              onChanged: (value) => onChanged(frame, value),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.value,
    required this.interactive,
    required this.onChanged,
  });
  final bool value;
  final bool interactive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 8),
      child: _AlertSwitchRow(
        title: 'Mở phiên Mỹ',
        subtitle: 'Nhắc khi phiên New York bắt đầu',
        value: value,
        enabled: interactive,
        onChanged: onChanged,
        icon: Icons.public_rounded,
      ),
    ),
  );
}

class _AlertSwitchRow extends StatelessWidget {
  const _AlertSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.icon,
  });
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 220),
    opacity: enabled ? 1 : .45,
    child: SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      secondary: Icon(
        icon ?? Icons.notifications_none_rounded,
        color: enabled && value
            ? context.appStatusColors.primary
            : AppColors.muted,
        size: 20,
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted, fontSize: 10),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: context.appStatusColors.primary,
      activeTrackColor: AppColors.lime,
    ),
  );
}
