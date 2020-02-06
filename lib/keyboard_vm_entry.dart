// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hardware_keyboard.dart';

// (Actually exists in dart:ui already)
// If we actually run on big endian machines, we'll need to do something smarter
// here. We don't use [Endian.Host] because it's not a compile-time
// constant and can't propagate into the set/get calls.
const Endian _kFakeHostEndian = Endian.little;

// If this value changes, update the encoding code in the following files:
//
//  * pointer_data.cc
//  * pointers.dart
//  * AndroidTouchProcessor.java
const int _kKeyEventDataFieldCount = 28;
const int _kKeyUpDownMask = 0x01;
const int _kKeyKnownKeyMask = 0x02;

class KeyboardEventState {
  KeyboardEventState({this.event, this.keysPressed, this.physicalKeysPressed});
  KeyEvent event;
  Set<LogicalKeyboardKey> keysPressed;
  Set<PhysicalKeyboardKey> physicalKeysPressed;
}

class KeyEventPacket {
  KeyEventPacket.unpack(ByteData packet) : _packet = packet, _parseOffset = 0 {
    const int bytesPerPointerData = _kKeyEventDataFieldCount * _stride;
    final int length = packet.lengthInBytes ~/ bytesPerPointerData;
    assert(length * bytesPerPointerData == packet.lengthInBytes);
    final List<KeyboardEventState> data = List<KeyboardEventState>(length);
    for (int i = 0; i < length; ++i) {
      KeyEvent event = _parseEvent(down);

      final int keysDownCount = _nextInt64();
      final List<int> keysDownCodes = List<int>(keysDownCount);
      for (int j = 0; j < keysDownCount; ++j) {
        keysDownCodes[j] = _nextInt64();
      }
      final int physicalKeysDownCount = _nextInt64();
      final List<int> physicalKeysDownCodes = List<int>(physicalKeysDownCount);
      for (int j = 0; j < physicalKeysDownCount; ++j) {
        physicalKeysDownCodes[j] = _nextInt64();
      }
    }
    _packet = null;
    _parseOffset = null;
  }

  KeyEvent _parseUnknownKey(bool down) {
    final Duration timestamp = Duration(microseconds: _nextInt64());

  }

  String _parseString() {
    final int stringLength = _nextInt64();
    final List<int> charCodes = List<int>(stringLength);
    for (int i = 0; i < stringLength; ++i) {
      charCodes.add(_nextInt64());
    }
    return String.fromCharCodes(charCodes);
  }

  KeyEvent _parseEvent(bool down) {
    final int flags = _nextInt64();
    final bool down = flags & _kKeyUpDownMask != 0;
    final int keyId = _nextInt64();
    final Duration timestamp = Duration(microseconds: _nextInt64());
    final int flutterLogicalKeyCode = _nextInt64();
    final int flutterPhysicalKeyCode = _nextInt64();
    final String keyLabel = _parseString();
    LogicalKeyboardKey logicalKey = LogicalKeyboardKey.findKeyByKeyId(flutterLogicalKeyCode) ?? LogicalKeyboardKey(
      keyId,
      keyLabel: keyLabel,
      debugName: kReleaseMode ? null : 'Key ${keyLabel.toUpperCase()}',
    );
    PhysicalKeyboardKey physicalKey = PhysicalKeyboardKey.findKeyByCode(flutterPhysicalKeyCode) ?? PhysicalKeyboardKey(
      keyId,
      debugName: kReleaseMode ? null : 'Key ${keyLabel.toUpperCase()}',
    );
    if (down) {
      return KeyDownEvent(timestamp: timestamp, logicalKey: logicalKey, physicalKey: physicalKey);
    } else {
      return KeyUpEvent(timestamp: timestamp, logicalKey: logicalKey, physicalKey: physicalKey);
    }
  }

  static const int _stride = Int64List.bytesPerElement;
  int _parseOffset;
  ByteData _packet;

  int _nextInt64() {
    return _packet.getInt64(_stride * _parseOffset++, _kFakeHostEndian);
  }

  List<KeyboardEventState> states;
}

@pragma('vm:entry-point')
// ignore: unused_element
bool _dispatchKeyEvent(ByteData packet) {
  // Runs in the zone where the instance was created.
  if (identical(HardwareKeyboard.instance.dispatchKeyEventZone, Zone.current)) {
    return HardwareKeyboard.instance.handleKeyEvent(KeyEventPacket.unpack(packet));
  } else {
    return HardwareKeyboard.instance.dispatchKeyEventZone.runUnary<bool, KeyEventPacket>(
      HardwareKeyboard.instance.handleKeyEvent,
      KeyEventPacket.unpack(packet),
    );
  }
}

