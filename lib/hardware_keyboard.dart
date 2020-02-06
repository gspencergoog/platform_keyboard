// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'keyboard_vm_entry.dart';

/// Defines the interface for keyboard key events.
///
/// Raw key events pass through as much information as possible from the
/// underlying platform's key events, which allows them to provide a high level
/// of fidelity but a low level of portability.
///
/// The event also provides an abstraction for the [physicalKey] and the
/// [logicalKey], describing the physical location of the key, and the logical
/// meaning of the key, respectively. These are more portable representations of
/// the key events, and should produce the same results regardless of platform.
///
/// See also:
///
///  * [LogicalKeyboardKey], an object that describes the logical meaning of a
///    key.
///  * [PhysicalKeyboardKey], an object that describes the physical location of
///    a key.
///  * [RawKeyDownEvent], a specialization for events representing the user
///    pressing a key.
///  * [RawKeyUpEvent], a specialization for events representing the user
///    releasing a key.
///  * [RawKeyboard], which uses this interface to expose key data.
///  * [RawKeyboardListener], a widget that listens for raw key events.
@immutable
abstract class KeyEvent extends Diagnosticable {
  /// Initializes fields for subclasses, and provides a const constructor for
  /// const subclasses.
  const KeyEvent({
    @required this.timestamp,
    @required this.logicalKey,
    @required this.physicalKey,
  });

  /// Returns true if the given [KeyboardKey] is pressed.
  bool isKeyPressed(LogicalKeyboardKey key) => HardwareKeyboard.instance.keysPressed.contains(key);

  /// Returns true if the given [KeyboardKey] is pressed.
  bool isPhysicalKeyPressed(PhysicalKeyboardKey key) => HardwareKeyboard.instance.physicalKeysPressed.contains(key);

  /// Returns true if a CTRL modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Use [isKeyPressed] if you need to know which control key was pressed.
  bool get isControlPressed {
    return isKeyPressed(LogicalKeyboardKey.controlLeft) || isKeyPressed(LogicalKeyboardKey.controlRight);
  }

  /// Returns true if a SHIFT modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Use [isKeyPressed] if you need to know which shift key was pressed.
  bool get isShiftPressed {
    return isKeyPressed(LogicalKeyboardKey.shiftLeft) || isKeyPressed(LogicalKeyboardKey.shiftRight);
  }

  /// Returns true if a ALT modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Note that the ALTGR key that appears on some keyboards is considered to be
  /// the same as [LogicalKeyboardKey.altRight] on some platforms (notably
  /// Android). On platforms that can distinguish between `altRight` and
  /// `altGr`, a press of `altGr` will not return true here, and will need to be
  /// tested for separately.
  ///
  /// Use [isKeyPressed] if you need to know which alt key was pressed.
  bool get isAltPressed {
    return isKeyPressed(LogicalKeyboardKey.altLeft) || isKeyPressed(LogicalKeyboardKey.altRight);
  }

  /// Returns true if a META modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Use [isKeyPressed] if you need to know which meta key was pressed.
  bool get isMetaPressed {
    return isKeyPressed(LogicalKeyboardKey.metaLeft) || isKeyPressed(LogicalKeyboardKey.metaRight);
  }

  /// Time of event, relative to an arbitrary start point.
  ///
  /// All events share the same start point.
  final Duration timestamp;

  /// Returns an object representing the physical location of this key.
  ///
  /// {@template flutter.services.RawKeyEvent.physicalKey}
  /// The [PhysicalKeyboardKey] ignores the key map, modifier keys (like SHIFT),
  /// and the label on the key. It describes the location of the key as if it
  /// were on a QWERTY keyboard regardless of the keyboard mapping in effect.
  ///
  /// [PhysicalKeyboardKey]s are used to describe and test for keys in a
  /// particular location.
  ///
  /// For instance, if you wanted to make a game where the key to the right of
  /// the CAPS LOCK key made the player move left, you would be comparing the
  /// result of this `physicalKey` with [PhysicalKeyboardKey.keyA], since that
  /// is the key next to the CAPS LOCK key on a QWERTY keyboard. This would
  /// return the same thing even on a French keyboard where the key next to the
  /// CAPS LOCK produces a "Q" when pressed.
  ///
  /// If you want to make your app respond to a key with a particular character
  /// on it regardless of location of the key, use [RawKeyEvent.logicalKey] instead.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [logicalKey] for the non-location specific key generated by this event.
  ///  * [character] for the character generated by this keypress (if any).
  final PhysicalKeyboardKey physicalKey;

  /// Returns an object representing the logical key that was pressed.
  ///
  /// {@template flutter.services.RawKeyEvent.logicalKey}
  /// This method takes into account the key map and modifier keys (like SHIFT)
  /// to determine which logical key to return.
  ///
  /// If you are looking for the character produced by a key event, use
  /// [RawKeyEvent.character] instead.
  ///
  /// If you are collecting text strings, use the [TextField] or
  /// [CupertinoTextField] widgets, since those automatically handle many of the
  /// complexities of managing keyboard input, like showing a soft keyboard or
  /// interacting with an input method editor (IME).
  /// {@endtemplate}
  final LogicalKeyboardKey logicalKey;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Duration>('timestamp', timestamp));
    properties.add(DiagnosticsProperty<LogicalKeyboardKey>('logicalKey', logicalKey));
    properties.add(DiagnosticsProperty<PhysicalKeyboardKey>('physicalKey', physicalKey));
  }
}

/// The user has pressed a key on the keyboard.
///
/// See also:
///
///  * [RawKeyboard], which uses this interface to expose key data.
class KeyDownEvent extends KeyEvent {
  /// Creates a key event that represents the user pressing a key.
  const KeyDownEvent({
    @required Duration timestamp,
    @required LogicalKeyboardKey logicalKey,
    @required PhysicalKeyboardKey physicalKey,
    this.character,
  }) : super(timestamp: timestamp, logicalKey: logicalKey, physicalKey: physicalKey);

  /// Returns the Unicode character (grapheme cluster) completed by this
  /// keystroke, if any.
  ///
  /// This will only return a character if this keystroke, combined with any
  /// preceding keystroke(s), generated a character, and only on a "key down"
  /// event. It will return null if no character has been generated by the
  /// keystroke (e.g. a "dead" or "combining" key), or if the corresponding key
  /// is a key without a visual representation, such as a modifier key or a
  /// control key.
  ///
  /// This can return multiple Unicode code points, since some characters (more
  /// accurately referred to as grapheme clusters) are made up of more than one
  /// code point.
  ///
  /// The `character` doesn't take into account edits by an input method editor
  /// (IME), or manage the visibility of the soft keyboard on touch devices. For
  /// composing text, use the [TextField] or [CupertinoTextField] widgets, since
  /// those automatically handle many of the complexities of managing keyboard
  /// input.
  ///
  /// Returns null if there is no character for this event.
  final String character;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('character', character));
  }
}

/// The user has released a key on the keyboard.
///
/// See also:
///
///  * [RawKeyboard], which uses this interface to expose key data.
class KeyUpEvent extends KeyEvent {
  /// Creates a key event that represents the user releasing a key.
  const KeyUpEvent({
    @required Duration timestamp,
    @required LogicalKeyboardKey logicalKey,
    @required PhysicalKeyboardKey physicalKey,
  }) : super(timestamp: timestamp, logicalKey: logicalKey, physicalKey: physicalKey);
}

typedef HardwareKeyboardEventCallback = bool Function(KeyEvent event);

/// An interface for listening to raw key events.
///
/// Raw key events pass through as much information as possible from the
/// underlying platform's key events, which makes them provide a high level of
/// fidelity but a low level of portability.
///
/// A [Keyboard] is useful for listening to raw key events and hardware
/// buttons that are represented as keys. Typically used by games and other apps
/// that use keyboards for purposes other than text entry.
///
/// See also:
///
///  * [KeyDownEvent] and [KeyUpEvent], the classes used to describe
///    specific raw key events.
///  * [RawKeyboardListener], a widget that listens for raw key events.
///  * [SystemChannels.keyEvent], the low-level channel used for receiving
///    events from the system.
class HardwareKeyboard {
  // Private to prevent instantiation or subclassing except through calling
  // instance.
  HardwareKeyboard._() : dispatchKeyEventZone = Zone.current;

  final Zone dispatchKeyEventZone;

  static final HardwareKeyboard instance = HardwareKeyboard._();

  final List<HardwareKeyboardEventCallback> _listeners = <HardwareKeyboardEventCallback>[];

  /// Calls the listener every time the user presses or releases a key.
  ///
  /// Listeners can be removed with [removeListener].
  void addListener(HardwareKeyboardEventCallback listener) => _listeners.add(listener);

  /// Stop calling the listener every time the user presses or releases a key.
  ///
  /// Listeners can be added with [addListener].
  void removeListener(HardwareKeyboardEventCallback listener) => _listeners.remove(listener);

  // Called by the platform code to pass along a synchronous key event.
  //
  // If the set of keys pressed changes when no event is fired (e.g. as a result
  // of a focus change), packet.event may be null.
  //
  // Returns true if any [KeyboardListener] returned true.
  bool handleKeyEvent(KeyEventPacket packet) {
    KeyEvent event;
    switch (packet.eventType) {
      case KeyEventPacketType.down:
        event = KeyDownEvent(logicalKey: packet.logicalKey, physicalKey: packet.physicalKey, timestamp: packet.timestamp, character: packet.character);
        break;
      case KeyEventPacketType.up:
        event = KeyUpEvent(logicalKey: packet.logicalKey, physicalKey: packet.physicalKey, timestamp: packet.timestamp);
        break;
      case KeyEventPacketType.sync:
        // Sync only synchronizes the keys down, it doesn't generate an event.
        break;
    }

    // Update the state of the keyboard before the event, since the state should
    // include the result of the event.
    _keysPressed = packet.keysPressed;
    _physicalKeysPressed = packet.physicalKeysPressed;

    if (event == null || _listeners.isEmpty) {
      return false;
    }
    bool handled = false;
    for (final HardwareKeyboardEventCallback listener in List<HardwareKeyboardEventCallback>.from(_listeners)) {
      if (_listeners.contains(listener)) {
        if (listener(event) == true) {
          handled = true;
        }
      }
    }
    return handled;
  }

  /// Returns the set of logical keys currently pressed.
  Set<LogicalKeyboardKey> get keysPressed => _keysPressed.toSet();
  Set<LogicalKeyboardKey> _keysPressed = <LogicalKeyboardKey>{};

  /// Returns the set of physical keys currently pressed.
  Set<PhysicalKeyboardKey> get physicalKeysPressed => _physicalKeysPressed.toSet();
  Set<PhysicalKeyboardKey> _physicalKeysPressed = <PhysicalKeyboardKey>{};

  /// Clears the list of keys returned from [keysPressed].
  ///
  /// This is used by the testing framework to make sure tests are hermetic.
  @visibleForTesting
  void clearKeysPressed() {
    _keysPressed.clear();
    // TODO(gspencergoog): Must we call the platform side to tell it to clear? This is just for
    // tests, so maybe not...
  }

  /// Clears the list of keys returned from [physicalKeysPressed].
  ///
  /// This is used by the testing framework to make sure tests are hermetic.
  @visibleForTesting
  void clearPhysicalKeysPressed() {
    _physicalKeysPressed.clear();
    // TODO(gspencergoog): Must we call the platform side to tell it to clear? This is just for
    // tests, so maybe not...
  }
}
