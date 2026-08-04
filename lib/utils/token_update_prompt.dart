import 'package:flutter/material.dart';
import '../services/token_update_service.dart';

/// Outcome of the launch-time token-update prompt. `updated` = user tapped
/// Update and the download succeeded. `failed` = user tapped Update and the
/// download failed. `dismissed` = user tapped Not Now (record the version so
/// we don't nag them again until the remote version bumps further).
enum TokenUpdatePromptOutcome { updated, failed, dismissed }

/// Shows the "Token database update available" modal and drives the download
/// inline when the user opts in. Returns the outcome so the caller can decide
/// whether to record a dismissal or fire a snackbar.
Future<TokenUpdatePromptOutcome> showTokenUpdatePrompt(
  BuildContext context,
  TokenUpdateResult result,
) async {
  final outcome = await showDialog<TokenUpdatePromptOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _TokenUpdateDialog(result: result),
  );
  return outcome ?? TokenUpdatePromptOutcome.dismissed;
}

class _TokenUpdateDialog extends StatefulWidget {
  final TokenUpdateResult result;
  const _TokenUpdateDialog({required this.result});

  @override
  State<_TokenUpdateDialog> createState() => _TokenUpdateDialogState();
}

class _TokenUpdateDialogState extends State<_TokenUpdateDialog> {
  bool _isDownloading = false;

  Future<void> _handleUpdate() async {
    setState(() => _isDownloading = true);
    final success = await TokenUpdateService.downloadUpdate(
      remoteVersion: widget.result.remoteVersion!,
      expectedSha256: widget.result.remoteSha256!,
      expectedSize: widget.result.remoteSize,
      updatedDate: widget.result.remoteUpdatedDate,
      minAppVersion: widget.result.minAppVersion,
    );
    if (!mounted) return;
    Navigator.of(context).pop(success
        ? TokenUpdatePromptOutcome.updated
        : TokenUpdatePromptOutcome.failed);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final sizeKb = r.remoteSize != null
        ? '${(r.remoteSize! / 1024).round()} KB'
        : null;

    final bodyLines = <String>[
      'A newer token database is available.',
      '',
      'Version: ${r.remoteVersion}',
      if (r.remoteUpdatedDate != null) 'Updated: ${r.remoteUpdatedDate}',
      if (sizeKb != null) 'Download size: $sizeKb',
    ];

    return AlertDialog(
      title: const Text('Token database update'),
      content: Text(
        bodyLines.join('\n'),
        style: const TextStyle(height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: _isDownloading
              ? null
              : () => Navigator.of(context)
                  .pop(TokenUpdatePromptOutcome.dismissed),
          child: const Text('Not now'),
        ),
        FilledButton.icon(
          onPressed: _isDownloading ? null : _handleUpdate,
          icon: _isDownloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download, size: 18),
          label: Text(_isDownloading ? 'Downloading…' : 'Update'),
        ),
      ],
    );
  }
}
