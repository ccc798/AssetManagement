import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/services/app_info_service.dart';
import '../../../core/services/version_service.dart';
import '../../providers/settings_provider.dart';

class VersionUpdatePage extends ConsumerStatefulWidget {
  const VersionUpdatePage({super.key});

  @override
  ConsumerState<VersionUpdatePage> createState() => _VersionUpdatePageState();
}

class _VersionUpdatePageState extends ConsumerState<VersionUpdatePage> {
  bool _isChecking = false;
  bool _isDownloading = false;
  String? _latestVersion;
  String? _downloadUrl;
  String? _errorMessage;
  String? _downloadProgress;

  Future<void> _checkForUpdate() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
      _latestVersion = null;
      _downloadUrl = null;
    });

    try {
      final versionInfo = await VersionService.checkForUpdate();
      if (versionInfo != null) {
        setState(() {
          _latestVersion = versionInfo.version;
          _downloadUrl = versionInfo.downloadUrl;
        });

        if (!VersionService.isNewVersion(versionInfo.version)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('version.latest', ref.read(localeCodeProvider)))),
            );
          }
        }
      } else {
        setState(() {
          _errorMessage = t('version.checkFailed', ref.read(localeCodeProvider));
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = t('version.checkFailed', ref.read(localeCodeProvider));
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _downloadUpdate() async {
    if (_downloadUrl == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = '0%';
    });

    try {
      final configAsync = ref.read(configProvider.future);
      final config = await configAsync;
      final useProxy = config.githubProxyEnabled;

      final result = await VersionService.downloadApkWithProxy(
        _downloadUrl!,
        useProxy,
        (received, total) {
          if (total != -1) {
            final progress = ((received / total) * 100).toStringAsFixed(0);
            setState(() {
              _downloadProgress = '$progress%';
            });
          }
        },
      );

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('version.downloadComplete', ref.read(localeCodeProvider)))),
          );
        }

        await VersionService.installApk(result);
      } else {
        throw Exception('下载失败');
      }
    } catch (e) {
      setState(() {
        _errorMessage = t('version.downloadTimeout', ref.read(localeCodeProvider));
      });
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = null;
      });
    }
  }

  Future<void> _openGithub() async {
    final url = VersionService.githubHomeUrl;
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = ref.read(localeCodeProvider);
    final hasUpdate = _latestVersion != null && VersionService.isNewVersion(_latestVersion!);

    return Scaffold(
      appBar: AppBar(title: Text(t('version.title', loc))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('version.currentVersion', loc),
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'v${AppInfoService.version}',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_latestVersion != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      t('version.latestVersion', loc),
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _latestVersion!,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasUpdate ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isChecking ? null : _checkForUpdate,
            icon: _isChecking 
                ? const CircularProgressIndicator() 
                : const Icon(Icons.update),
            label: Text(_isChecking ? t('version.checking', loc) : t('version.checkUpdate', loc)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: const Color.fromARGB(255, 255, 200, 200),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
          if (hasUpdate && _downloadUrl != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadUpdate,
              icon: _isDownloading 
                  ? const CircularProgressIndicator() 
                  : const Icon(Icons.download),
              label: _isDownloading 
                  ? Text(_downloadProgress ?? t('version.downloading', loc))
                  : Text(t('version.download', loc)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.code, color: Colors.black87),
              title: Text(t('version.github', loc)),
              subtitle: const Text('https://github.com/ccc798/AssetManagement'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openGithub,
            ),
          ),
        ],
      ),
    );
  }
}