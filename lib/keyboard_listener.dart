// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'hardware_keyboard.dart';

/// A widget that calls a callback whenever the user presses or releases a key
/// on a keyboard.
///
/// A [KeyboardListener] is useful for listening to raw key events and
/// hardware buttons that are represented as keys. Typically used by games and
/// other apps that use keyboards for purposes other than text entry.
///
/// For text entry, consider using a [EditableText], which integrates with
/// on-screen keyboards and input method editors (IMEs).
///
/// See also:
///
///  * [EditableText], which should be used instead of this widget for text
///    entry.
class KeyboardListener extends StatefulWidget {
  /// Creates a widget that receives raw keyboard events.
  ///
  /// For text entry, consider using a [EditableText], which integrates with
  /// on-screen keyboards and input method editors (IMEs).
  ///
  /// The [focusNode] and [child] arguments are required and must not be null.
  ///
  /// The [autofocus] argument must not be null.
  const KeyboardListener({
    Key key,
    @required this.focusNode,
    this.autofocus = false,
    this.onKey,
    @required this.child,
  }) : assert(focusNode != null),
        assert(autofocus != null),
        assert(child != null),
        super(key: key);

  /// Controls whether this widget has keyboard focus.
  final FocusNode focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  /// Called whenever this widget receives a raw keyboard event.
  ///
  /// Should return true if the key has been handled, and should not be
  /// propagated further.
  final HardwareKeyboardEventCallback onKey;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.child}
  final Widget child;

  @override
  _KeyboardListenerState createState() => _KeyboardListenerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
  }
}

class _KeyboardListenerState extends State<KeyboardListener> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(KeyboardListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    _detachKeyboardIfAttached();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (widget.focusNode.hasFocus)
      _attachKeyboardIfDetached();
    else
      _detachKeyboardIfAttached();
  }

  bool _listening = false;

  void _attachKeyboardIfDetached() {
    if (_listening)
      return;
    HardwareKeyboard.instance.addListener(_handleKeyEvent);
    _listening = true;
  }

  void _detachKeyboardIfAttached() {
    if (!_listening)
      return;
    HardwareKeyboard.instance.removeListener(_handleKeyEvent);
    _listening = false;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (widget.onKey != null)
      return widget.onKey(event);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      child: widget.child,
    );
  }
}
