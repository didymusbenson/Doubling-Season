import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/artwork_manager.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  int _cacheSize = 0;
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadCacheSize();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'Version ${packageInfo.version} (${packageInfo.buildNumber})';
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
              'Doubling Season',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            if (_version.isNotEmpty)
              Text(
                _version,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
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
                      'Doubling Season is a token tracker for Magic: The Gathering. '
                      'This project is a labor of love for the Magic community and is '
                      'committed to being 100% free and ad free forever. Your support '
                      'helps keep Doubling Season free.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

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
                      'Token data sourced from the Cockatrice project.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Card images © Wizards of the Coast LLC '
                      'Images provided by Scryfall. Scryfall is not produced by or endorsed '
                      'by Wizards of the Coast.\n\n'
                      'Doubling Season is unofficial Fan Content permitted under the Fan '
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
                        const Text('Artwork Cache'),
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
                        label: const Text('Clear Artwork Cache'),
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
                  applicationName: 'Doubling Season',
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
