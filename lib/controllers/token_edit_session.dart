import 'package:flutter/material.dart';

import '../models/item.dart';
import '../providers/token_provider.dart';

enum TokenEditableField { name, powerToughness, type, abilities }

/// Owns the transient text/focus state for an inline token edit.
///
/// The existing [Item] is mutated in place and persisted through
/// [TokenProvider], so unrelated runtime and artwork fields are preserved.
class TokenEditSession extends ChangeNotifier {
  TokenEditSession({required this.item, required this.tokenProvider}) {
    for (final field in TokenEditableField.values) {
      final node = FocusNode(debugLabel: 'token-${field.name}');
      node.addListener(() {
        if (!node.hasFocus && activeField == field) {
          // commit() absorbs persistence errors into its bool/error contract.
          // Intentionally do not leave a raw async Future in a focus listener.
          _commitAfterFocusLoss(field);
        }
      });
      focusNodes[field] = node;
      controllers[field] = TextEditingController();
    }
  }

  final Item item;
  final TokenProvider tokenProvider;
  final Map<TokenEditableField, TextEditingController> controllers = {};
  final Map<TokenEditableField, FocusNode> focusNodes = {};

  TokenEditableField? activeField;
  final Map<TokenEditableField, String> _originalValues = {};
  Future<bool>? _pendingCommit;
  Object? lastCommitError;
  bool _disposed = false;

  bool get isEditing => activeField != null;
  bool get isCommitting => _pendingCommit != null;

  String valueFor(TokenEditableField field) => switch (field) {
        TokenEditableField.name => item.name,
        TokenEditableField.powerToughness => item.pt,
        TokenEditableField.type => item.type,
        TokenEditableField.abilities => item.abilities,
      };

  Future<bool> begin(TokenEditableField field) async {
    if (_disposed) return false;
    if (activeField == field) return true;
    if (activeField != null && !await commitActive()) return false;
    if (_disposed) return false;
    final originalValue = valueFor(field);
    _originalValues[field] = originalValue;
    controllers[field]!
      ..text = originalValue
      ..selection = TextSelection.collapsed(
        offset: originalValue.length,
      );
    activeField = field;
    lastCommitError = null;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && activeField == field) focusNodes[field]!.requestFocus();
    });
    return true;
  }

  /// Commits the raw field value. Empty values intentionally remain valid,
  /// matching the previous detail screen.
  Future<bool> commit([TokenEditableField? field]) {
    final pending = _pendingCommit;
    if (pending != null) return pending;
    final target = field ?? activeField;
    if (_disposed) return Future.value(false);
    if (target == null) return Future.value(true);
    if (activeField != target) return Future.value(false);

    final operation = _performCommit(target);
    _pendingCommit = operation;
    notifyListeners();
    return operation.whenComplete(() {
      _pendingCommit = null;
      if (!_disposed) notifyListeners();
    });
  }

  Future<bool> _performCommit(TokenEditableField target) async {
    final value = controllers[target]!.text;
    final original = _originalValues[target] ?? valueFor(target);
    try {
      _assign(target, value);
      await tokenProvider.updateItem(item);
    } catch (error) {
      // Keep the user's controller text and active editor intact. Restore the
      // in-memory model so failed edits do not leak into provider rebuilds.
      try {
        _assign(target, original);
        await item.save();
      } catch (_) {
        // The original persistence failure remains the actionable error.
      }
      lastCommitError = error;
      if (!_disposed) notifyListeners();
      return false;
    }

    activeField = null;
    _originalValues.remove(target);
    lastCommitError = null;
    if (!_disposed) notifyListeners();
    return true;
  }

  void _assign(TokenEditableField field, String value) {
    switch (field) {
      case TokenEditableField.name:
        item.name = value;
      case TokenEditableField.powerToughness:
        item.pt = value;
      case TokenEditableField.type:
        item.type = value;
      case TokenEditableField.abilities:
        item.abilities = value;
    }
  }

  Future<void> _commitAfterFocusLoss(TokenEditableField field) async {
    await commit(field);
  }

  /// Safe gate for collapse, off-card transfer, or opening a sheet.
  /// Callers must proceed only when this returns true.
  Future<bool> commitActive() => commit();

  @override
  void dispose() {
    _disposed = true;
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final node in focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }
}
