/// WebDAV 和 AI 配置（纯 Dart 类）
class BackupConfig {
  const BackupConfig({
    this.webdavUrl = '',
    this.webdavUsername = '',
    this.webdavPassword = '',
    this.webdavPath = '/AssetManagement',
    this.autoBackup = false,
    this.backupIntervalDays = 7,
    this.lastBackupAt,
    this.aiBaseUrl = 'https://api.openai.com/v1',
    this.aiApiKey = '',
    this.aiModel = 'gpt-4o-mini',
    this.aiMaxTokens = 4096,
    this.aiTemperature = 0.1,
    this.themeMode = 'system',
    this.colorSeed = 0xFF5C6BC0,
    this.locale = 'zh',
  });

  final String webdavUrl;
  final String webdavUsername;
  final String webdavPassword;
  final String webdavPath;
  final bool autoBackup;
  final int backupIntervalDays;
  final DateTime? lastBackupAt;
  final String aiBaseUrl;
  final String aiApiKey;
  final String aiModel;
  final int aiMaxTokens;
  final double aiTemperature;
  final String themeMode;
  final int colorSeed;
  final String locale;

  static const BackupConfig default_ = BackupConfig();

  Map<String, dynamic> toJson() => {
        'webdavUrl': webdavUrl,
        'webdavUsername': webdavUsername,
        'webdavPassword': webdavPassword,
        'webdavPath': webdavPath,
        'autoBackup': autoBackup,
        'backupIntervalDays': backupIntervalDays,
        'lastBackupAt': lastBackupAt?.toIso8601String(),
        'aiBaseUrl': aiBaseUrl,
        'aiApiKey': aiApiKey,
        'aiModel': aiModel,
        'aiMaxTokens': aiMaxTokens,
        'aiTemperature': aiTemperature,
        'themeMode': themeMode,
        'colorSeed': colorSeed,
        'locale': locale,
      };

  factory BackupConfig.fromJson(Map<String, dynamic> json) => BackupConfig(
        webdavUrl: json['webdavUrl'] as String? ?? '',
        webdavUsername: json['webdavUsername'] as String? ?? '',
        webdavPassword: json['webdavPassword'] as String? ?? '',
        webdavPath: json['webdavPath'] as String? ?? '/AssetManagement',
        autoBackup: json['autoBackup'] as bool? ?? false,
        backupIntervalDays: json['backupIntervalDays'] as int? ?? 7,
        lastBackupAt: json['lastBackupAt'] != null
            ? DateTime.parse(json['lastBackupAt'] as String)
            : null,
        aiBaseUrl: json['aiBaseUrl'] as String? ?? 'https://api.openai.com/v1',
        aiApiKey: json['aiApiKey'] as String? ?? '',
        aiModel: json['aiModel'] as String? ?? 'gpt-4o-mini',
        aiMaxTokens: json['aiMaxTokens'] as int? ?? 4096,
        aiTemperature: (json['aiTemperature'] as num?)?.toDouble() ?? 0.1,
        themeMode: json['themeMode'] as String? ?? 'system',
        colorSeed: json['colorSeed'] as int? ?? 0xFF5C6BC0,
        locale: json['locale'] as String? ?? 'zh',
      );

  BackupConfig copyWith({
    String? webdavUrl,
    String? webdavUsername,
    String? webdavPassword,
    String? webdavPath,
    bool? autoBackup,
    int? backupIntervalDays,
    DateTime? lastBackupAt,
    String? aiBaseUrl,
    String? aiApiKey,
    String? aiModel,
    int? aiMaxTokens,
    double? aiTemperature,
    String? themeMode,
    int? colorSeed,
    String? locale,
  }) {
    return BackupConfig(
      webdavUrl: webdavUrl ?? this.webdavUrl,
      webdavUsername: webdavUsername ?? this.webdavUsername,
      webdavPassword: webdavPassword ?? this.webdavPassword,
      webdavPath: webdavPath ?? this.webdavPath,
      autoBackup: autoBackup ?? this.autoBackup,
      backupIntervalDays: backupIntervalDays ?? this.backupIntervalDays,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiModel: aiModel ?? this.aiModel,
      aiMaxTokens: aiMaxTokens ?? this.aiMaxTokens,
      aiTemperature: aiTemperature ?? this.aiTemperature,
      themeMode: themeMode ?? this.themeMode,
      colorSeed: colorSeed ?? this.colorSeed,
      locale: locale ?? this.locale,
    );
  }
}
