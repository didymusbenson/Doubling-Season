import 'dart:async';
import 'package:flutter/material.dart';
import '../services/table_support_service.dart';
import 'game_drawer_body.dart';
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

/// Uses the existing support service in either the drawer or its standalone
/// host. Product ownership, pending purchases and errors are never presentation
/// state and continue to be controlled by that service.
class TableSupportContent extends StatefulWidget {
  const TableSupportContent({super.key, this.onClose, this.embedded = false});
  final VoidCallback? onClose;
  final bool embedded;

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
    builder: (context, _) {
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded)
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
          const SizedBox(height: 16),
          Text(
            widget.embedded ? 'Always free to play' : 'Free, with no ads.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Support is optional and adds a cosmetic heart badge. Every game feature is included for everyone.',
            textAlign: TextAlign.center,
          ),
          if (service.loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          for (final product in service.products)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final action = service.owned.contains(product.id)
                      ? const Icon(Icons.check_circle_outline)
                      : FilledButton(
                          onPressed: service.pending || service.restoring
                              ? null
                              : () => service.buy(product),
                          child: Text(product.price),
                        );
                  final description = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TableSupportService.tierNames[TableSupportService
                            .productIds
                            .indexOf(product.id)],
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(product.description),
                    ],
                  );
                  return bounds.maxWidth < 260
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            description,
                            const SizedBox(height: 8),
                            action,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: description),
                            const SizedBox(width: 12),
                            action,
                          ],
                        );
                },
              ),
            ),
          if (service.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(service.message!, textAlign: TextAlign.center),
            ),
          if (service.tier >= 3)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(
                alignment: WrapAlignment.center,
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
            ),
          if (service.available)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: service.pending || service.restoring
                    ? null
                    : service.restore,
                child: const Text('Restore purchases'),
              ),
            ),
        ],
      );
      return widget.embedded
          ? GameDrawerBody(
              centered: service.products.isEmpty,
              scrollKey: const PageStorageKey('drawer-support'),
              child: content,
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: content,
            );
    },
  );
}
