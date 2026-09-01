import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_diagnostics_service.dart';
import 'push_notification_service.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.minimumBuild,
    required this.updateRequired,
    required this.apkUrl,
    required this.releaseNotes,
  });

  final String latestVersion;
  final int latestBuild;
  final int minimumBuild;
  final bool updateRequired;
  final String apkUrl;
  final String releaseNotes;

  bool shouldShowFor(int currentBuild) {
    return latestBuild > currentBuild || minimumBuild > currentBuild;
  }

  bool isForcedFor(int currentBuild) {
    return updateRequired || minimumBuild > currentBuild;
  }

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: '${json['latestVersion'] ?? ''}'.trim(),
      latestBuild: _parseInt(json['latestBuild'], fallback: 0),
      minimumBuild: _parseInt(json['minimumBuild'], fallback: 0),
      updateRequired: json['updateRequired'] == true,
      apkUrl: '${json['apkUrl'] ?? ''}'.trim(),
      releaseNotes: '${json['releaseNotes'] ?? ''}'.trim(),
    );
  }

  static int _parseInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }
}

class AppUpdateService {
  static const String _versionUrl =
      'https://cifraband-api.onrender.com/app-version';
  static const Duration _timeout = Duration(seconds: 10);
  static const MethodChannel _apkInstallerChannel = MethodChannel(
    'cifra_band/apk_installer',
  );

  static bool _checking = false;
  static bool _dialogShown = false;

  static Future<void> checkForUpdate(BuildContext context) async {
    if (_checking || _dialogShown) return;

    _checking = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      debugPrint(
        'Verificando atualizacao: instalada ${packageInfo.version}+$currentBuild',
      );
      AppDiagnosticsService.log(
        'Verificando atualizacao do app',
        context: {
          'installedVersion': packageInfo.version,
          'installedBuild': currentBuild,
        },
      );

      final response = await http.get(Uri.parse(_versionUrl)).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Falha ao consultar versão do app: ${response.statusCode}');
        AppDiagnosticsService.log(
          'Falha HTTP ao consultar versao do app',
          level: 'warning',
          context: {'statusCode': response.statusCode},
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;

      final updateInfo = AppUpdateInfo.fromJson(decoded);
      debugPrint(
        'Versao remota: ${updateInfo.latestVersion}+${updateInfo.latestBuild}',
      );

      if (!updateInfo.shouldShowFor(currentBuild)) return;
      if (updateInfo.apkUrl.isEmpty) return;
      if (!context.mounted) return;

      unawaited(
        PushNotificationService.showLocalNotification(
          title: 'Nova atualização disponível',
          body:
              'Cifra Band ${updateInfo.latestVersion}+${updateInfo.latestBuild} já pode ser instalada.',
          data: {
            'type': 'app_update_available',
            'latestBuild': '${updateInfo.latestBuild}',
          },
        ),
      );
      AppDiagnosticsService.log(
        'Atualizacao disponivel',
        context: {
          'latestVersion': updateInfo.latestVersion,
          'latestBuild': updateInfo.latestBuild,
          'forced': updateInfo.isForcedFor(currentBuild),
        },
      );

      if (Navigator.maybeOf(context, rootNavigator: true) == null) {
        debugPrint('Atualizacao encontrada, mas Navigator ainda indisponivel.');
        return;
      }

      _dialogShown = true;
      await _showUpdateDialog(
        context: context,
        packageInfo: packageInfo,
        updateInfo: updateInfo,
        forceUpdate: updateInfo.isForcedFor(currentBuild),
      );
    } catch (error) {
      debugPrint('Erro ao verificar atualização do app: $error');
      AppDiagnosticsService.log(
        'Erro ao verificar atualizacao do app',
        level: 'warning',
        error: error,
      );
    } finally {
      _checking = false;
    }
  }

  static Future<void> _showUpdateDialog({
    required BuildContext context,
    required PackageInfo packageInfo,
    required AppUpdateInfo updateInfo,
    required bool forceUpdate,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (dialogContext) {
        return PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            backgroundColor: const Color(0xFF171821),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Nova versão disponível'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instalada: ${packageInfo.version}+${packageInfo.buildNumber}',
                ),
                const SizedBox(height: 6),
                Text(
                  'Disponível: ${updateInfo.latestVersion}+${updateInfo.latestBuild}',
                ),
                if (updateInfo.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    updateInfo.releaseNotes,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Depois'),
                ),
              FilledButton(
                onPressed: () {
                  final navigator = Navigator.of(
                    dialogContext,
                    rootNavigator: true,
                  );
                  final downloadContext = navigator.context;
                  navigator.pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!downloadContext.mounted) return;
                    unawaited(
                      _downloadAndInstallApk(
                        context: downloadContext,
                        updateInfo: updateInfo,
                      ),
                    );
                  });
                },
                child: const Text('Atualizar'),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _downloadAndInstallApk({
    required BuildContext context,
    required AppUpdateInfo updateInfo,
  }) async {
    if (!Platform.isAndroid) {
      await _openReleasePage(updateInfo.apkUrl);
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ApkDownloadDialog(updateInfo: updateInfo),
    );
  }

  static Future<File> _downloadApk({
    required AppUpdateInfo updateInfo,
    required ValueChanged<double> onProgress,
  }) async {
    final uri = await _resolveApkDownloadUri(updateInfo);
    final request = http.Request('GET', uri);
    final client = http.Client();
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppDiagnosticsService.log(
        'Download da APK falhou por HTTP',
        level: 'error',
        context: {'statusCode': response.statusCode},
      );
      throw HttpException('Download retornou HTTP ${response.statusCode}.');
    }

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/html')) {
      AppDiagnosticsService.log(
        'Link de atualizacao retornou HTML em vez de APK',
        level: 'error',
        context: {'contentType': contentType, 'url': '$uri'},
      );
      throw const FormatException('O link recebido nao aponta para uma APK.');
    }

    final tempDirectory = await getTemporaryDirectory();
    final apkFile = File(
      '${tempDirectory.path}/cifra-band-${updateInfo.latestVersion}-build-${updateInfo.latestBuild}.apk',
    );

    final output = apkFile.openWrite();
    var receivedBytes = 0;
    final totalBytes = response.contentLength ?? 0;

    try {
      await for (final chunk in response.stream) {
        receivedBytes += chunk.length;
        output.add(chunk);

        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }
    } finally {
      await output.close();
      client.close();
    }

    if (await apkFile.length() == 0) {
      AppDiagnosticsService.log(
        'APK baixada ficou vazia',
        level: 'error',
        context: {'path': apkFile.path},
      );
      throw const FileSystemException('APK baixada vazia.');
    }

    onProgress(1);
    return apkFile;
  }

  static Future<Uri> _resolveApkDownloadUri(AppUpdateInfo updateInfo) async {
    final configuredUri = Uri.parse(updateInfo.apkUrl);
    final lowerPath = configuredUri.path.toLowerCase();

    if (lowerPath.endsWith('.apk')) {
      return configuredUri;
    }

    if (configuredUri.host == 'github.com' &&
        configuredUri.path.contains('/releases/latest')) {
      return _resolveGithubLatestApkUri();
    }

    return configuredUri;
  }

  static Future<Uri> _resolveGithubLatestApkUri() async {
    final response = await http
        .get(
          Uri.parse(
            'https://api.github.com/repos/Alefexz/cifra_band/releases/latest',
          ),
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw HttpException(
        'GitHub retornou HTTP ${response.statusCode} ao buscar release.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Resposta invalida do GitHub.');
    }

    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('Release sem lista de assets.');
    }

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;

      final name = '${asset['name'] ?? ''}'.toLowerCase();
      final downloadUrl = '${asset['browser_download_url'] ?? ''}'.trim();

      if (name.endsWith('.apk') && downloadUrl.isNotEmpty) {
        return Uri.parse(downloadUrl);
      }
    }

    throw const FileSystemException('Nenhuma APK encontrada no release.');
  }

  static Future<void> _openReleasePage(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ApkDownloadDialog extends StatefulWidget {
  const _ApkDownloadDialog({required this.updateInfo});

  final AppUpdateInfo updateInfo;

  @override
  State<_ApkDownloadDialog> createState() => _ApkDownloadDialogState();
}

class _ApkDownloadDialogState extends State<_ApkDownloadDialog> {
  double _progress = 0;
  String _status = 'Preparando download...';
  bool _failed = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_startDownload);
  }

  Future<void> _startDownload() async {
    if (_started) return;
    _started = true;

    try {
      final apkFile = await AppUpdateService._downloadApk(
        updateInfo: widget.updateInfo,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress.clamp(0, 1);
            _status = _progress >= 1
                ? 'Download concluido. Abrindo instalador...'
                : 'Baixando atualizacao ${(_progress * 100).clamp(0, 99).round()}%';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _progress = 1;
        _status = 'Download concluido. Abrindo instalador...';
      });

      await AppUpdateService._apkInstallerChannel.invokeMethod<bool>(
        'installApk',
        {'path': apkFile.path},
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (error) {
      debugPrint('Falha ao baixar/instalar APK: $error');
      AppDiagnosticsService.log(
        'Falha ao baixar ou instalar APK',
        level: 'error',
        error: error,
        context: {
          'latestVersion': widget.updateInfo.latestVersion,
          'latestBuild': widget.updateInfo.latestBuild,
          'apkUrl': widget.updateInfo.apkUrl,
        },
      );
      if (!mounted) return;
      setState(() {
        _failed = true;
        _status = 'Nao consegui baixar a atualizacao.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _failed,
      child: AlertDialog(
        backgroundColor: const Color(0xFF171821),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Atualizando Cifra Band'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: _failed ? null : _progress,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                color: const Color(0xFF22C55E),
              ),
            ),
            if (_failed) ...[
              const SizedBox(height: 14),
              Text(
                'Confira sua internet ou abra a pagina da versao.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
              ),
            ],
          ],
        ),
        actions: [
          if (_failed)
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('Fechar'),
            ),
          if (_failed)
            FilledButton(
              onPressed: () =>
                  AppUpdateService._openReleasePage(widget.updateInfo.apkUrl),
              child: const Text('Abrir pagina'),
            ),
        ],
      ),
    );
  }
}
