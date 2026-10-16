class MarketAlertSettings {
  const MarketAlertSettings({
    this.enabled = true,
    this.assetSettings = const {
      'BTCUSDT': {'H4': true, 'Ngày': true, 'Tuần': false, 'Tháng': false},
      'ETHUSDT': {'H4': false, 'Ngày': false, 'Tuần': false, 'Tháng': false},
      'XAUUSD': {'H4': true, 'Ngày': true, 'Tuần': false, 'Tháng': false},
      'XAGUSD': {'H4': false, 'Ngày': false, 'Tuần': false, 'Tháng': false},
    },
    this.usSession = true,
  });

  final bool enabled;
  final Map<String, Map<String, bool>> assetSettings;
  final bool usSession;

  MarketAlertSettings copyWith({
    bool? enabled,
    Map<String, Map<String, bool>>? assetSettings,
    bool? usSession,
  }) => MarketAlertSettings(
    enabled: enabled ?? this.enabled,
    assetSettings: assetSettings ?? this.assetSettings,
    usSession: usSession ?? this.usSession,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'assetSettings': assetSettings,
    'usSession': usSession,
  };

  factory MarketAlertSettings.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assetSettings'];
    final assets = <String, Map<String, bool>>{};
    if (rawAssets is Map) {
      for (final entry in rawAssets.entries) {
        final rawFrames = entry.value;
        if (rawFrames is Map) {
          assets[entry.key.toString()] = {
            for (final frame in rawFrames.entries)
              frame.key.toString(): frame.value == true,
          };
        }
      }
    }
    return MarketAlertSettings(
      enabled: json['enabled'] != false,
      assetSettings: assets.isEmpty
          ? const {
              'BTCUSDT': {
                'H4': true,
                'Ngày': true,
                'Tuần': false,
                'Tháng': false,
              },
              'ETHUSDT': {
                'H4': false,
                'Ngày': false,
                'Tuần': false,
                'Tháng': false,
              },
              'XAUUSD': {
                'H4': true,
                'Ngày': true,
                'Tuần': false,
                'Tháng': false,
              },
              'XAGUSD': {
                'H4': false,
                'Ngày': false,
                'Tuần': false,
                'Tháng': false,
              },
            }
          : assets,
      usSession: json['usSession'] != false,
    );
  }
}
