import 'dart:async';
import 'package:flutter/material.dart';
import '../services/table_support_service.dart';
import 'table_modal_frame.dart';

Future<void> showTableSupport(BuildContext context, {int quarterTurns = 0}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      builder: (context) => TableModalFrame(
        quarterTurns: quarterTurns,
        child: TableSupportContent(onClose: () => Navigator.pop(context)),
      ),
    );

/// The same optional support workflow can be hosted by the game drawer without
/// opening a second route. Store behavior and pending/failure state stay owned
/// by the existing support service.
class TableSupportContent extends StatefulWidget {
  const TableSupportContent({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  State<TableSupportContent> createState() => _TableSupportContentState();
}

class _TableSupportContentState extends State<TableSupportContent> {
  final service = TableSupportService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(service.initialize());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Support Tripling Table',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (widget.onClose != null)
                MergeSemantics(
                  child: Semantics(
                    label: 'Close support',
                    child: IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Free, with no ads. Support is optional and adds a cosmetic heart badge. Every game feature is included for everyone.',
          ),
          const SizedBox(height: 20),
          Center(
            child: Icon(
              Icons.favorite,
              size: 48,
              color: Color(
                service.tier == 1
                    ? 0xffdf7474
                    : service.tier == 2
                    ? 0xff83b7ce
                    : service.heartColor,
              ),
            ),
          ),
          if (service.loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          for (final product in service.products)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                TableSupportService.tierNames[TableSupportService.productIds
                    .indexOf(product.id)],
              ),
              subtitle: Text(product.description),
              trailing: service.owned.contains(product.id)
                  ? const Icon(Icons.check_circle_outline)
                  : FilledButton(
                      onPressed: service.pending || service.restoring
                          ? null
                          : () => service.buy(product),
                      child: Text(product.price),
                    ),
            ),
          if (service.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(service.message!),
            ),
          if (service.tier >= 3)
            Wrap(
              spacing: 8,
              children: [
                for (final color in [
                  0xffded5a4,
                  0xff83b7ce,
                  0xffb498ca,
                  0xffdf7474,
                  0xff93bd9b,
                ])
                  MergeSemantics(
                    child: Semantics(
                      label: 'Choose badge color',
                      child: IconButton(
                        onPressed: () => service.setHeartColor(color),
                        icon: Icon(Icons.favorite, color: Color(color)),
                      ),
                    ),
                  ),
              ],
            ),
          if (service.available)
            TextButton(
              onPressed: service.pending || service.restoring
                  ? null
                  : service.restore,
              child: const Text('Restore purchases'),
            ),
        ],
      ),
    ),
  );
}
