// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:platform_keyboard/keyboard_listener.dart';

import 'keyboard_vm_entry.dart';

/// Defines the interface for keyboard key events.
///
/// The event provides an abstraction for the [physicalKey] and [logicalKey],
/// describing the physical location of the key, and the logical meaning of the
/// key, respectively. For [KeyDownEvent]s, the character produced by the event
/// (if any) is also included.
///
/// See also:
///
///  * [LogicalKeyboardKey], an object that describes the logical meaning of a
///    key.
///  * [PhysicalKeyboardKey], an object that describes the physical location of
///    a key.
///  * [KeyDownEvent], a subclass for events representing the user
///    pressing a key.
///  * [KeyUpEvent], a subclass for events representing the user
///    releasing a key.
///  * [KeySyncEvent], a subclass for events representing the user
///    pressing a key when Flutter doesn't have focus.
///  * [KeyCancelEvent], a subclass for events representing the user
///    releasing a key when Flutter doesn't have focus.
///  * [HardwareKeyboard], which can be listened to for key events.
///  * [HardwareKeyboardListener], a widget that listens for hardware key events.
@immutable
abstract class KeyEvent with DiagnosticableMixin implements Diagnosticable {
  /// Initializes fields for subclasses, and provides a const constructor for
  /// const subclasses.
  const KeyEvent({
    @required this.timestamp,
    @required this.logicalKey,
    @required this.physicalKey,
  });

  /// Time of event, relative to an arbitrary start point.
  ///
  /// All events share the same timestamp origin.
  final Duration timestamp;

  /// Returns an object representing the physical location of this key.
  ///
  /// {@template flutter.services.KeyEvent.physicalKey}
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
  /// on it regardless of location of the key, use [KeyEvent.logicalKey] instead.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [logicalKey] for the non-location specific key generated by this event.
  ///  * [character] for the character generated by this keypress (if any).
  final PhysicalKeyboardKey physicalKey;

  /// Returns an object representing the logical key that was pressed.
  ///
  /// {@template flutter.services.KeyEvent.logicalKey}
  /// This method takes into account the key map and modifier keys (like SHIFT)
  /// to determine which logical key to return.
  ///
  /// If you are looking for the character produced by a key event, use
  /// [KeyEvent.character] instead.
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

/// An event indicating that the user has pressed a key down on the keyboard.
///
/// See also:
///
///  * [HardwareKeyboard], which produces this event.
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
  /// preceding keystroke(s), generated a character. It will return null if no
  /// character has been generated by the keystroke (e.g. a "dead" or
  /// "combining" key), or if the corresponding key is a key without a visual
  /// representation, such as a modifier key or a control key.
  ///
  /// This can return multiple Unicode code points, since some characters (more
  /// accurately referred to as grapheme clusters) are made up of more than one
  /// code point.
  ///
  /// The `character` doesn't take into account edits by an input method editor
  /// (IME). For composing text, use the [TextField] or [CupertinoTextField]
  /// widgets, since those automatically handle many of the complexities of
  /// managing keyboard input.
  ///
  /// Returns null if there is no character for this event.
  final String character;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('character', character));
  }
}

/// An event indicating that the user has released a key on the keyboard.
///
/// See also:
///
///  * [HardwareKeyboard], which produces this event.
class KeyUpEvent extends KeyEvent {
  /// Creates a key event that represents the user releasing a key.
  const KeyUpEvent({
    @required Duration timestamp,
    @required LogicalKeyboardKey logicalKey,
    @required PhysicalKeyboardKey physicalKey,
  }) : super(timestamp: timestamp, logicalKey: logicalKey, physicalKey: physicalKey);
}

/// The user has released a key on the keyboard after Flutter lost input focus.
///
/// This is effectively a key up event, but is generated because the application
/// lost focus before the key was released, and so the key up event was
/// delivered to another application, or dropped by the operating system.
///
/// The application is expected to update state related to this key event, but
/// not to trigger user actions as a result of the event.
///
/// See also:
///
///  * [HardwareKeyboard], which produces this event.
class KeyCancelEvent extends KeyEvent {
  /// Creates a key event that represents the user releasing a key outside of
  /// the current focus.
  const KeyCancelEvent({
    @required Duration timestamp,
    @required LogicalKeyboardKey logicalKey,
    @required PhysicalKeyboardKey physicalKey,
  }) : super(timestamp: timestamp, logicalKey: logicalKey, physicalKey: physicalKey);
}

/// The user has pressed a key on the keyboard before the current application
/// gained focus.
///
/// This is effectively a key down event, but is generated because the application
/// gained focus after the key was pressed, and so the key down was delivered to
/// another application.
///
/// The application is expected to update state related to this key event, but
/// not to trigger user actions as a result of the event.
///
/// See also:
///
///  * [HardwareKeyboard], which produces this event.
class KeySyncEvent extends KeyEvent {
  /// Creates a key event that represents the user releasing a key outside of
  /// the current focus.
  const KeySyncEvent({
    @required Duration timestamp,
    @required LogicalKeyboardKey logicalKey,
    @required PhysicalKeyboardKey physicalKey,
  }) : super(timestamp: timestamp, logicalKey: logicalKey, physicalKey: physicalKey);
}

typedef HardwareKeyboardEventCallback = bool Function(KeyEvent event);

/// An singleton interface for listening to hardware key events.
///
/// A [HardwareKeyboard] is useful for listening to key events and hardware
/// buttons that are represented as keys. Typically used by games and other apps
/// that use keyboards for purposes other than text entry.
///
/// Text entry is a much more complex affair than just listening to key events:
/// input method editors, software keyboards, platform key mappings, and other
/// details need to be taken into account to provide a good experience for
/// users. Consequently, using the events generated by this class to enter text
/// is discouraged. Instead, use [EditableText], [TextField], [TextFormField]
/// and [CupertinoTextField] to receive text input.
///
/// Processed text input is not as useful for things like keyboard shortcuts and
/// keyboard-controlled gaming or other keyboard controlled apps. That is why
/// this class exists.
///
/// See also:
///
///  * [KeyDownEvent], [KeyUpEvent], [KeyCancelEvent], and [KeySyncEvent], the
///    classes used to describe specific key events.
///  * [HardwareKeyboardListener], a widget that listens for hardware key events.
///  * [Shortcuts] and [Actions], widgets designed to allow binding sets of keys
///    to actions.
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
  // Returns true if any [KeyboardListener] returned true.
  KeyEventResponse handleKeyEventPacket(KeyEventPacket packet) {
    switch (packet.eventType) {
      case KeyEventPacketType.down:
        final bool handled = simulateKeyDownEvent(
          logicalKey: packet.logicalKey,
          physicalKey: packet.physicalKey,
          timestamp: packet.timestamp,
          character: packet.character,
        );
        return handled ? KeyEventResponse.handled : KeyEventResponse.skip;
      case KeyEventPacketType.up:
        final bool handled = simulateKeyUpEvent(
          logicalKey: packet.logicalKey,
          physicalKey: packet.physicalKey,
          timestamp: packet.timestamp,
        );
        return handled ? KeyEventResponse.handled : KeyEventResponse.skip;
      case KeyEventPacketType.sync:
        simulateKeySyncEvent(
          logicalKey: packet.logicalKey,
          physicalKey: packet.physicalKey,
          timestamp: packet.timestamp,
        );
        break;
      case KeyEventPacketType.cancel:
        simulateKeyCancelEvent(
          logicalKey: packet.logicalKey,
          physicalKey: packet.physicalKey,
          timestamp: packet.timestamp,
        );
        break;
    }
    // Only key down/up can actually mark an event as handled.  Sync and cancel
    // always return skip.
    return KeyEventResponse.skip;
  }

  // Distributes the given key event to listeners and returns whether or not one
  // of them handled it.
  bool _handleEvent(KeyEvent event) {
    // Update the state of the keyboard before sending the event to listeners,
    // since the state should include the result of the event.
    if (event is KeyDownEvent || event is KeySyncEvent) {
      _keysDown[event.physicalKey] = event.logicalKey;
    } else if (event is KeyUpEvent || event is KeyCancelEvent) {
      _keysDown.remove(event.physicalKey);
    }

    if (_listeners.isEmpty) {
      return false;
    }

    bool handled = false;
    // Operate on a copy so that if listeners are removed during execution, the list is still sane.
    for (final HardwareKeyboardEventCallback listener in List<HardwareKeyboardEventCallback>.from(_listeners)) {
      if (_listeners.contains(listener)) {
        if (listener(event) == true) {
          handled = true;
        }
      }
    }

    // Only key down/up can actually mark an event as handled.  Sync and cancel
    // always return false.
    return (event is KeyDownEvent || event is KeyUpEvent) && handled;
  }

  /// Simulates sending a hardware key down event through the system channel.
  ///
  /// This only simulates key presses coming from a physical keyboard, not from a
  /// soft keyboard.
  ///
  /// It is intended for testing purposes only.
  ///
  /// See also:
  ///
  ///  - [simulateKeyUpEvent] to simulate a key up event.
  ///  - [simulateKeySyncEvent] to simulate a key sync event.
  ///  - [simulateKeyCancelEvent] to simulate a key cancel event.
  @visibleForTesting
  bool simulateKeyDownEvent({
    @required Duration timestamp,
    @required LogicalKeyboardKey logicalKey,
    @required PhysicalKeyboardKey physicalKey,
    String character,
  }) {
    assert(timestamp != null);
    assert(logicalKey != null);
    assert(physicalKey != null);
    return _handleEvent(
      KeyDownEvent(
        timestamp: timestamp,
        logicalKey: logicalKey,
        physicalKey: physicalKey,
        character: character,
      ),
    );
  }

  /// Simulates sending a hardware key up event through the system channel.
  ///
  /// This only simulates key presses coming from a physical keyboard, not from a
  /// soft keyboard.
  ///
  /// It is intended for testing purposes only.
  ///
  /// See also:
  ///
  ///  - [simulateKeyDownEvent] to simulate a key down event.
  ///  - [simulateKeySyncEvent] to simulate a key sync event.
  ///  - [simulateKeyCancelEvent] to simulate a key cancel event.
  @visibleForTesting
  bool simulateKeyUpEvent({
    @required Duration timestamp,
    @required LogicalKeyboardKey logicalKey,
    @required PhysicalKeyboardKey physicalKey,
  }) {
    assert(timestamp != null);
    assert(logicalKey != null);
    assert(physicalKey != null);
    return _handleEvent(
      KeyUpEvent(
        timestamp: timestamp,
        logicalKey: logicalKey,
        physicalKey: physicalKey,
      ),
    );
  }

  /// Simulates sending a hardware key sync event through the system channel.
  ///
  /// This event typically happens when Flutter regains focus, and a key is
  /// already being held down.
  ///
  /// This only simulates key presses coming from a physical keyboard, not from a
  /// soft keyboard.
  ///
  /// Key sync events just add to the set of keys which Flutter thinks are pressed,
  /// they shouldn't be handled as key down events, or generate user actions.
  ///
  /// It is intended for testing purposes only.
  ///
  /// See also:
  ///
  ///  - [simulateKeyDownEvent] to simulate a key down event.
  ///  - [simulateKeyUpEvent] to simulate a key up event.
  ///  - [simulateKeySyncEvent] to simulate a key sync event.
  ///  - [simulateKeyCancelEvent] to simulate a key cancel event.
  @visibleForTesting
  void simulateKeySyncEvent({
    @required Duration timestamp,
    @required LogicalKeyboardKey logicalKey,
    @required PhysicalKeyboardKey physicalKey,
  }) {
    assert(timestamp != null);
    assert(logicalKey != null);
    assert(physicalKey != null);
    _handleEvent(
      KeySyncEvent(
        timestamp: timestamp,
        logicalKey: logicalKey,
        physicalKey: physicalKey,
      ),
    );
  }

  /// Simulates sending a hardware key cancel event through the system channel.
  ///
  /// This event typically happens when Flutter loses focus, and a key is
  /// released while Flutter doesn't have focus.
  ///
  /// This only simulates key events coming from a physical keyboard, not from a
  /// soft keyboard.
  ///
  /// Key cancel events just remove keys from the set of keys which Flutter
  /// thinks are pressed, they shouldn't be handled as key up events, or
  /// generate user actions.
  ///
  /// It is intended for testing purposes only.
  ///
  /// See also:
  ///
  ///  - [simulateKeyDownEvent] to simulate a key down event.
  ///  - [simulateKeyUpEvent] to simulate a key up event.
  ///  - [simulateKeySyncEvent] to simulate a key sync event.
  @visibleForTesting
  void simulateKeyCancelEvent({
    @required Duration timestamp,
    @required LogicalKeyboardKey logicalKey,
    @required PhysicalKeyboardKey physicalKey,
  }) {
    assert(timestamp != null);
    assert(logicalKey != null);
    assert(physicalKey != null);
    _handleEvent(
      KeyCancelEvent(
        timestamp: timestamp,
        logicalKey: logicalKey,
        physicalKey: physicalKey,
      ),
    );
  }

  /// Returns true if the logical key, or any of its synonyms, is currently pressed.
  ///
  /// Will also return true for the [LogicalKeyboardKey.synonyms] of keys which
  /// have them. For example, testing for [LogicalKeyboardKey.shift] will return
  /// true if [LogicalKeyboardKey.shiftLeft] or [LogicalKeyboardKey.shiftRight]
  /// are pressed. Testing for [LogicalKeyboardKey.shiftLeft] specifically will
  /// only return true if [LogicalKeyboardKey.shiftLeft] is pressed;
  ///
  /// See also:
  ///
  ///  * [LogicalKeyboardKey] for information about what a logical key represents.
  ///  * [LogicalKeyboardKey.synonyms] for information about key synonyms.
  bool isKeyPressed(LogicalKeyboardKey key) {
    return keysPressed.intersection(<LogicalKeyboardKey>{key, ...key.synonyms}).isNotEmpty;
  }

  /// Returns true if the physical `key` is currently pressed.
  ///
  /// See also:
  ///
  ///  * [PhysicalKeyboardKey] for information about what a physical key represents.
  bool isPhysicalKeyPressed(PhysicalKeyboardKey key) => _keysDown.containsKey(key);

  /// Returns true if a CTRL modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Use [isKeyPressed] with [LogicalKeyboardKey.controlLeft] or
  /// [LogicalKeyboardKey.controlRight] if you need to know which control key
  /// was pressed.
  bool get isControlPressed => isKeyPressed(LogicalKeyboardKey.control);

  /// Returns true if a SHIFT modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Use [isKeyPressed] with [LogicalKeyboardKey.shiftLeft] or
  /// [LogicalKeyboardKey.shiftRight] if you need to know which shift key
  /// was pressed.
  bool get isShiftPressed => isKeyPressed(LogicalKeyboardKey.shift);

  /// Returns true if a ALT modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Note that the ALTGR key that appears on some keyboards is considered to be
  /// the same as [LogicalKeyboardKey.altRight] on some platforms (notably
  /// Android). On platforms that can distinguish between `altRight` and
  /// `altGr`, a press of `altGr` will not return true here, and will need to be
  /// tested for separately.
  ///
  /// Use [isKeyPressed] with [LogicalKeyboardKey.altLeft] or
  /// [LogicalKeyboardKey.altRight] if you need to know which alt key was
  /// pressed.
  bool get isAltPressed => isKeyPressed(LogicalKeyboardKey.alt);

  /// Returns true if a META modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Use [isKeyPressed] with [LogicalKeyboardKey.metaLeft] or
  /// [LogicalKeyboardKey.metaRight] if you need to know which meta key was
  /// pressed.
  bool get isMetaPressed => isKeyPressed(LogicalKeyboardKey.meta);

  final Map<PhysicalKeyboardKey, LogicalKeyboardKey> _keysDown = <PhysicalKeyboardKey, LogicalKeyboardKey>{};

  /// Returns the set of keys currently pressed.
  Set<LogicalKeyboardKey> get keysPressed => _keysDown.values.toSet();

  /// Returns the set of physical keys currently pressed.
  Set<PhysicalKeyboardKey> get physicalKeysPressed => _keysDown.keys.toSet();

  /// Clears the list of keys returned from [keysPressed] and [physicalKeysPressed].
  ///
  /// This is used by the testing framework to make sure tests are hermetic.
  @visibleForTesting
  void clearKeysPressed() {
    _keysDown.clear();
    // TODO(gspencergoog): Must we call the platform side to tell it to clear
    // its state? This is just for tests, so maybe not...
  }
}
