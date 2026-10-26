import 'package:doubling_season/widgets/artwork_credit_caption.dart';
import 'package:flutter/material.dart';

String tabletArtworkArtist(String? url, String? artist) {
  if (url?.startsWith('tablet-art:') == true ||
      url?.startsWith('file://') == true) {
    return 'user uploaded';
  }
  final credit = artist?.trim() ?? '';
  return credit.isEmpty || credit == 'Custom URL' ? 'Artist unknown' : credit;
}

/// Keep the original application's nib, typography and single accessible credit.
class TabletArtworkCredit extends StatelessWidget {
  const TabletArtworkCredit({super.key, this.url, this.artist});
  final String? url, artist;
  @override
  Widget build(BuildContext context) => ArtworkCreditCaption(
    artist: tabletArtworkArtist(url, artist),
    alignment: WrapAlignment.center,
  );
}
