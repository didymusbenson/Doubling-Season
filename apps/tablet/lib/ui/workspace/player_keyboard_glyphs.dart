import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

/// Follow the active Flutter platform, including the browser host platform.
abstract final class PlayerKeyboardGlyphs {
  static bool _apple(BuildContext context) =>
      switch (Theme.of(context).platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => true,
        _ => false,
      };

  static IconData shift(BuildContext context, {required bool selected}) =>
      _apple(context)
      ? (selected ? CupertinoIcons.shift_fill : CupertinoIcons.shift)
      : Icons.arrow_upward;
  static IconData delete(BuildContext context) =>
      _apple(context) ? CupertinoIcons.delete_left : Icons.backspace_outlined;
  static IconData returnKey(BuildContext context) =>
      _apple(context) ? CupertinoIcons.return_icon : Icons.keyboard_return;
  static IconData cursorLeft(BuildContext context) =>
      _apple(context) ? CupertinoIcons.arrow_left : Icons.keyboard_arrow_left;
  static IconData cursorRight(BuildContext context) =>
      _apple(context) ? CupertinoIcons.arrow_right : Icons.keyboard_arrow_right;
  static IconData selection(BuildContext context) =>
      _apple(context) ? CupertinoIcons.selection_pin_in_out : Icons.select_all;
  static IconData more(BuildContext context) =>
      _apple(context) ? CupertinoIcons.ellipsis : Icons.more_horiz;
  static IconData paste(BuildContext context) =>
      _apple(context) ? CupertinoIcons.doc_on_clipboard : Icons.content_paste;
  static IconData minus(BuildContext context) =>
      _apple(context) ? CupertinoIcons.minus : Icons.remove;
  static IconData close(BuildContext context) =>
      _apple(context) ? CupertinoIcons.xmark : Icons.close;
}
