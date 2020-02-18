// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'hardware_keyboard.dart';

/// A widget that calls a callback whenever it has focus and the user presses or
/// releases a key on a keyboard.
///
/// A [HardwareKeyboardListener] is useful for listening to hardware key events
/// and hardware buttons that are represented as keys. Typically used by games
/// and other apps that use keyboards for purposes other than text entry.
///
/// For text entry, consider using a [EditableText], which integrates with
/// on-screen keyboards and input method editors (IMEs).
///
/// See also:
///
///  * [EditableText], which should be used instead of this widget for text
///    entry.
class HardwareKeyboardListener extends StatefulWidget {
  /// Creates a widget that receives hardware keyboard events.
  ///
  /// For text entry, consider using a [EditableText], which integrates with
  /// on-screen keyboards and input method editors (IMEs).
  ///
  /// The [child] argument is required and must not be null.
  const HardwareKeyboardListener({
    Key key,
    this.onKey,
    @required this.child,
  }) : assert(child != null), 
       super(key: key);

  /// Called whenever this widget receives a hardware keyboard event.
  ///
  /// Should return true if the key has been handled, and should not be
  /// propagated further.
  ///
  /// Does nothing if set to null.
  final HardwareKeyboardEventCallback onKey;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.child}
  final Widget child;

  @override
  _HardwareKeyboardListenerState createState() => _HardwareKeyboardListenerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('onKey', value: onKey != null, ifTrue: 'onKey'));
  }
}

class _HardwareKeyboardListenerState extends State<HardwareKeyboardListener> {
  @override
  void dispose() {
    _detachKeyboardIfAttached();
    super.dispose();
  }

  void _handleFocusChanged(bool value) {
    if (value)
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

  bool _handleKeyEvent(KeyEvent event) => widget.onKey?.call(event) ?? false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _handleFocusChanged,
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      child: widget.child,
    );
  }
}
