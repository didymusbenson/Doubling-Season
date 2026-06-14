import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/token_database.dart';
import '../models/heart_style.dart';
import '../services/iap_service.dart';
import '../services/token_update_service.dart';
import '../utils/artwork_manager.dart';
import '../utils/constants.dart';
import '../utils/whats_new_content.dart';
import '../widgets/heart_icon.dart';
import '../widgets/purchase_menu.dart';
import 'heart_customization_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _versionKey = '';
  int _cacheSize = 0;
  int _customUploadsSize = 0;
  bool _isLoadingCache = true;
  bool _isLoadingCustom = true;
  HeartStyle? _collectorHeartStyle;

  int _activeDbVersion = 0;
  int? _activeTokenCount;
  String? _activeDbUpdatedDate;
  bool _hasOverride = false;
  bool _isCheckingForUpdate = false;
  bool _isDownloading = false;
  TokenUpdateResult? _lastCheckResult;

  static const String _koFiUrl = 'https://ko-fi.com/loosetie';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadCacheSize();
    _loadCustomUploadsSize();
    _loadCollectorHeartStyle();
    _loadTokenDbInfo();
  }

  Future<void> _loadCollectorHeartStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final styleId =
        prefs.getString(IAPService.heartStyleKey) ?? 'rainbow';
    if (mounted) {
      setState(() {
        _collectorHeartStyle = HeartStyle.getAllStyles().firstWhere(
          (s) => s.id == styleId,
          orElse: () => HeartStyle.rainbow(),
        );
      });
    }
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = 'Version ${packageInfo.version} (${packageInfo.buildNumber})';
      _versionKey = packageInfo.version;
    });
  }

  Future<void> _loadCacheSize() async {
    final size = await ArtworkManager.getTotalCacheSize();
    if (mounted) {
      setState(() {
        _cacheSize = size;
        _isLoadingCache = false;
      });
    }
  }

  Future<void> _clearArtworkCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all cached artwork?'),
        content: const Text(
          'This will remove all downloaded token artwork, including for existing tokens.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ArtworkManager.clearAllArtwork();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Artwork cache cleared')),
        );
        // Reload cache size
        await _loadCacheSize();
      }
    }
  }

  Future<void> _loadCustomUploadsSize() async {
    final size = await ArtworkManager.getCustomUploadsSize();
    if (mounted) {
      setState(() {
        _customUploadsSize = size;
        _isLoadingCustom = false;
      });
    }
  }

  Future<void> _clearCustomUploads() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all imported artwork?'),
        content: const Text(
          'This will remove all custom uploaded token artwork and deck box images.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ArtworkManager.clearCustomUploads();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imported artwork cleared')),
        );
        await _loadCustomUploadsSize();
      }
    }
  }

  /// Reads the active manifest (override if newer than bundled, else bundled)
  /// and a fresh token-count parse for display. Cheap enough to run on every
  /// About-screen open since the parse is ~940 entries.
  Future<void> _loadTokenDbInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeVersion = prefs.getInt(PreferenceKeys.tokenDbVersion) ?? 0;
      final hasOverride = await TokenUpdateService.hasOverride();

      final bundledStr = await rootBundle.loadString(AssetPaths.tokenManifest);
      final bundledManifest =
          jsonDecode(bundledStr) as Map<String, dynamic>;
      final bundledVersion = bundledManifest['version'] as int;

      String? updatedDate = bundledManifest['updated'] as String?;
      if (hasOverride && activeVersion > bundledVersion) {
        // The override manifest holds the truer "updated" string.
        final db = TokenDatabase();
        await db.loadTokens();
        // Re-read prefs because loadTokens may have rewritten the version.
        // (Token count is now known.)
        if (!mounted) return;
        setState(() {
          _activeDbVersion =
              prefs.getInt(PreferenceKeys.tokenDbVersion) ?? activeVersion;
          _activeTokenCount = db.allTokens.length;
          _activeDbUpdatedDate = updatedDate; // best-effort fallback
          _hasOverride = hasOverride;
        });
        return;
      }

      // Common path: bundled is active. Count tokens via a fresh load.
      final db = TokenDatabase();
      await db.loadTokens();
      if (!mounted) return;
      setState(() {
        _activeDbVersion = bundledVersion;
        _activeTokenCount = db.allTokens.length;
        _activeDbUpdatedDate = updatedDate;
        _hasOverride = hasOverride;
      });
    } catch (_) {
      // Non-fatal — card just shows what it has.
    }
  }

  Future<void> _checkForTokenUpdate() async {
    setState(() {
      _isCheckingForUpdate = true;
      _lastCheckResult = null;
    });
    final result = await TokenUpdateService.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _isCheckingForUpdate = false;
      _lastCheckResult = result;
    });
  }

  Future<void> _downloadTokenUpdate() async {
    final result = _lastCheckResult;
    if (result == null ||
        result.remoteVersion == null ||
        result.remoteSha256 == null) {
      return;
    }

    setState(() => _isDownloading = true);
    final success = await TokenUpdateService.downloadUpdate(
      remoteVersion: result.remoteVersion!,
      expectedSha256: result.remoteSha256!,
      expectedSize: result.remoteSize,
      updatedDate: result.remoteUpdatedDate,
      minAppVersion: result.minAppVersion,
    );
    if (!mounted) return;
    setState(() => _isDownloading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Token database updated. Restart token search to see new tokens.',
          ),
        ),
      );
      await _loadTokenDbInfo();
      // Clear the "available" banner — we just installed it.
      if (mounted) setState(() => _lastCheckResult = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update failed. Your token data is unchanged.'),
        ),
      );
    }
  }

  Future<void> _revertTokenDbToBundled() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset token database?'),
        content: const Text(
          'This will remove the downloaded token data and revert to the '
          'version bundled with this app build.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await TokenUpdateService.revertToBundled();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Reverted to built-in database. Restart token search to apply.',
        ),
      ),
    );
    await _loadTokenDbInfo();
    setState(() => _lastCheckResult = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),

            // App Icon/Title
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/AppIconSource.png',
                width: 100,
                height: 100,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Tripling Season',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            if (_version.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _version,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  if (hasWhatsNewContent(_versionKey)) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => showWhatsNewDialog(context),
                      child: Text(
                        "What's new?",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

            const SizedBox(height: 32),

            // Description
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tripling Season is a token tracker for Magic: The Gathering. '
                      'This project is a labor of love for the Magic community and is '
                      'committed to being 100% free and ad free forever.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            
            // Support
            _buildSupportCard(),

            const SizedBox(height: 16),
            // Features
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to Use',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      icon: Icons.add_circle,
                      text: 'Tap + button to search 300+ token types',
                    ),
                    _buildFeatureItem(
                      icon: Icons.touch_app,
                      text: 'Tap any token to edit, add counters, or split stacks',
                    ),
                    _buildFeatureItem(
                      icon: Icons.calculate,
                      text: 'Adjust multiplier for doubling effects',
                    ),
                    _buildFeatureItem(
                      icon: Icons.save,
                      text: 'Save your current board state as a deck to reuse later',
                    ),
                    _buildFeatureItem(
                      icon: Icons.menu,
                      text: 'Open tools menu for untap all, board wipe, and more',
                    ),
                  ],
                ),
              ),
            ),



            const SizedBox(height: 16),

            // Credits
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Credits',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Token data sourced from MTGJSON (mtgjson.com), licensed under MIT.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Card images © Wizards of the Coast LLC '
                      'Images provided by Scryfall. Scryfall is not produced by or endorsed '
                      'by Wizards of the Coast.\n\n'
                      'Tripling Season is unofficial Fan Content permitted under the Fan '
                      'Content Policy. Not approved/endorsed by Wizards. Portions of the '
                      'materials used are property of Wizards of the Coast. © Wizards of '
                      'the Coast LLC.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Token Database
            _buildTokenDatabaseCard(),

            const SizedBox(height: 16),

            // Storage Management
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Downloaded Artwork Cache'),
                        _isLoadingCache
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                ArtworkManager.formatCacheSize(_cacheSize),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cacheSize > 0 ? _clearArtworkCache : null,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear Downloaded Artwork'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Custom Uploads Cache'),
                        _isLoadingCustom
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                ArtworkManager.formatCacheSize(_customUploadsSize),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _customUploadsSize > 0 ? _clearCustomUploads : null,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear Imported Artwork'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Open Source Licenses
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Tripling Season',
                  applicationVersion: _version,
                  applicationIcon: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/AppIconSource.png',
                      width: 60,
                      height: 60,
                    ),
                  ),
                ),
                icon: const Icon(Icons.description),
                label: const Text('View Open Source Licenses'),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  HeartStyle _currentHeartStyle() {
    final iap = IAPService();
    if (iap.shouldShowRainbowHeart()) {
      return _collectorHeartStyle ?? HeartStyle.rainbow();
    }
    if (iap.shouldShowBlueHeart()) return HeartStyle.blue();
    if (iap.shouldShowRedHeart()) return HeartStyle.red();
    return HeartStyle.red(); // placeholder, only shown with outline icon
  }

  Future<void> _handleSupportButtonTap() async {
    if (kIsWeb) {
      final uri = Uri.parse(_koFiUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Ko-fi link')),
        );
      }
      return;
    }

    final iap = IAPService();
    if (iap.hasCollectorTier()) {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const HeartCustomizationScreen(),
        ),
      );
      if (changed == true) {
        await _loadCollectorHeartStyle();
      }
      return;
    }

    if (iap.hasPlayTier()) {
      await _showUpgradeDialog(
        nextTier: 'Collector',
        scrollTo: 'collector',
      );
      return;
    }

    if (iap.hasThankYouTier()) {
      await _showUpgradeDialog(
        nextTier: 'Play',
        scrollTo: 'play',
      );
      return;
    }

    final purchased = await PurchaseMenu.show(context);
    if (purchased == true && mounted) {
      await _loadCollectorHeartStyle();
      setState(() {});
    }
  }

  Future<void> _showUpgradeDialog({
    required String nextTier,
    required String scrollTo,
  }) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade to $nextTier?'),
        content: Text(
          'Thank you for supporting Tripling Season! Would you like to upgrade to the $nextTier tier?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('View Tiers'),
          ),
        ],
      ),
    );

    if (shouldOpen == true && mounted) {
      final purchased =
          await PurchaseMenu.show(context, scrollToTier: scrollTo);
      if (purchased == true && mounted) {
        await _loadCollectorHeartStyle();
        setState(() {});
      }
    }
  }

  Widget _buildSupportCard() {
    final iap = IAPService();
    final showFilledHeart = iap.hasAnyTier();
    final heartStyle = _currentHeartStyle();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Support',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                InkWell(
                  onTap: iap.hasCollectorTier() ? _handleSupportButtonTap : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: showFilledHeart
                        ? HeartIcon(style: heartStyle, size: 32)
                        : Icon(
                            Icons.favorite_border,
                            size: 32,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              iap.hasCollectorTier()
                  ? 'Thanks for your Collector-tier support! Tap the heart to customize your badge.'
                  : 'You can support ongoing development of Tripling Season by leaving a tip.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleSupportButtonTap,
                icon: Icon(
                  kIsWeb ? Icons.open_in_new : Icons.favorite,
                ),
                label: Text(
                  kIsWeb
                      ? 'Support via Ko-fi'
                      : iap.hasCollectorTier()
                          ? 'Customize Heart Badge'
                          : iap.hasAnyTier()
                              ? 'Upgrade Tier'
                              : 'Support Tripling Season',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenDatabaseCard() {
    final result = _lastCheckResult;
    final updateAvailable = result?.available == true;
    final hasCheckedAndUpToDate =
        result != null && !result.available && result.error == null;
    final hasCheckError = result?.error != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Token Database',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _tokenDbInfoRow(
              'Version',
              _activeDbVersion > 0 ? _activeDbVersion.toString() : '—',
            ),
            if (_activeDbUpdatedDate != null)
              _tokenDbInfoRow('Updated', _activeDbUpdatedDate!),
            if (_activeTokenCount != null)
              _tokenDbInfoRow('Tokens', _activeTokenCount.toString()),
            const SizedBox(height: 12),
            if (updateAvailable)
              _tokenDbStatusBanner(
                color: Colors.green,
                icon: Icons.system_update_alt,
                text:
                    'Update available (v${result!.remoteVersion}). Tap below to download.',
              )
            else if (hasCheckedAndUpToDate)
              _tokenDbStatusBanner(
                color: Colors.green,
                icon: Icons.check_circle_outline,
                text: 'Up to date',
              )
            else if (hasCheckError)
              _tokenDbStatusBanner(
                color: Colors.grey,
                icon: Icons.cloud_off,
                text: result!.error!,
              ),
            if (updateAvailable || hasCheckedAndUpToDate || hasCheckError)
              const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isCheckingForUpdate || _isDownloading)
                    ? null
                    : (updateAvailable
                        ? _downloadTokenUpdate
                        : _checkForTokenUpdate),
                icon: _isCheckingForUpdate || _isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(updateAvailable
                        ? Icons.download
                        : Icons.refresh),
                label: Text(_tokenDbButtonLabel(updateAvailable)),
              ),
            ),
            if (_hasOverride) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed:
                      (_isCheckingForUpdate || _isDownloading)
                          ? null
                          : _revertTokenDbToBundled,
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Reset to Built-in Database'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _tokenDbButtonLabel(bool updateAvailable) {
    if (_isDownloading) return 'Downloading…';
    if (_isCheckingForUpdate) return 'Checking…';
    if (updateAvailable) return 'Download Update';
    return 'Check for Updates';
  }

  Widget _tokenDbInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _tokenDbStatusBanner({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
