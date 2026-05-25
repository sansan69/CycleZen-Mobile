import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cyclezen/core/theme/app_theme.dart';
import 'package:cyclezen/data/services/update_service.dart';

/// Full-screen or dialog that shows update info, downloads the APK,
/// and triggers installation.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  /// Show the dialog. Returns true if user started the update flow.
  static Future<bool?> show(BuildContext context, UpdateInfo info) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !info.mandatory,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double _progress = 0;
  bool _downloading = false;
  bool _downloadComplete = false;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
    });

    try {
      final path = await UpdateService.instance.downloadApk(
        widget.info.apkUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (!mounted) return;

      setState(() {
        _downloadComplete = true;
        _downloading = false;
        _progress = 1.0;
      });

      // Give a brief moment to show "Download complete", then install
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      await UpdateService.instance.installApk(path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.system_update, color: AppTheme.greenAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Update Available', style: TextStyle(fontSize: 18)),
                Text(
                  'v${widget.info.currentVersion} → v${widget.info.version}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.greenAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Changelog ──
            if (widget.info.changelog.isNotEmpty) ...[
              Text('What\'s new:', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.info.changelog,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            // ── Progress bar ──
            if (_downloading || _downloadComplete) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  color: _downloadComplete
                      ? AppTheme.greenAccent
                      : AppTheme.secondaryTeal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _downloadComplete
                    ? 'Download complete — installing...'
                    : 'Downloading... ${(_progress * 100).round()}%',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],

            if (widget.info.mandatory)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'This update is required to continue.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (!widget.info.mandatory && !_downloading)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
        if (_error != null && !_downloading)
          TextButton(
            onPressed: _startDownload,
            child: const Text('Retry'),
          ),
        if (!_downloading && !_downloadComplete && _error == null)
          ElevatedButton.icon(
            onPressed: _startDownload,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.greenAccent,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}
