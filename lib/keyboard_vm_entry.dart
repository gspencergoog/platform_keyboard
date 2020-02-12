// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hardware_keyboard.dart';

/// Key events are encoded as follows:
///
/// For the top-level synchronous keyboard event, a Map<int, dynamic> that
/// includes the timestamp, event type, and payload.
///
/// For key up/down payloads:
///  - LogicalKeyboardKey for this event
///  - PhysicalKeyboardKey for this event
///  - A list of logical keys pressed.
///  - A list of physical keys pressed.
///
/// In addition, on key down payloads:
///  - An optional  String containing the character or characters produced by
///   this key down, if any.
///
/// For sync payloads:
///  - logical keys down: a list of LogicalKeyboardKey
///  - physical keys down: a list of PhysicalKeyboardKey
///
/// Each LogicalKeyboardKey is encoded as a Map<int, dynamic> which has the following fields:
///  - int keyId
///  - String keyLabel
///
/// Each PhysicalKeyboardKey is encoded as a Map<int, dynamic> which has the following fields:
///  - int keyId
///  - String keyLabel
///
/// Obviously, the field id constants here must match the equivalent constants
/// in each platform's encoding code.
///
/// The numbers used are chosen to be unique, non-overlapping ranges, but that
/// is only to be able to assert that numbers from one layer are not used at
/// another: no actual collision would occur if there were duplicate field
/// numbers in the payload fields and the event fields, for instance, we just
/// wouldn't be able to tell (in the asserts) if a payload field number had been
/// used at the event level or vice-versa.

// Top level event field id constants.

const int _kTimestamp = 1; // Duration timestamp encoded as a single int representing microseconds.
const int _kEventType = 2; // int representing  event type (KeyEventPacketType.down/up/sync).
const int _kPayload = 3; // Map<int, dynamic> containing the event payload
const Set<int> _kEventFields = <int>{
  _kTimestamp,
  _kEventType,
  _kPayload,
};

// Payload field id constants.
const int _kLogicalKey = 100; // LogicalKeyboardKey for this event
const int _kPhysicalKey = 200; // PhysicalKeyboardKey for this event
const int _kLogicalKeysPressed = 300; // a list of LogicalKeyboardKey parameters
const int _kPhysicalKeysPressed = 400; // a list of PhysicalKeyboardKey parameters
const int _kCharacterProduced = 500; // String: character produced by this key down, if any.
const Set<int> _kPayloadFields = <int>{
  _kLogicalKey,
  _kPhysicalKey,
  _kLogicalKeysPressed,
  _kPhysicalKeysPressed,
  _kCharacterProduced,
};

// LogicalKeyboardKey field id constants
const int _kLogicalKeyId = 10000; // int keyId
const int _kLogicalKeyLabel = 20000; // String keyLabel
const Set<int> _kLogicalKeyFields = <int>{
  _kLogicalKeyId,
  _kLogicalKeyLabel,
};

const int _kPhysicalKeyId = 10000000; // int physicalKeyCode
const int _kPhysicalKeyLabel = 20000000; // String keyLabel
const Set<int> _kPhysicalKeyFields = <int>{
  _kPhysicalKeyId,
  _kPhysicalKeyLabel,
};

enum KeyEventPacketType {
  down, // 0
  up, // 1
  sync, // 2
  cancel, // 3
}

enum KeyEventResponse {
  skip, // 0
  handled, // 1
}

/// An interface for describing platform key events to
/// [HardwareKeyboard.handleKeyEvent].
///
/// See also:
///
///  * [PlatformKeyEventPacket], for a packet that parses raw [ByteData] from the
///    platform and turns it into key event data.
///  * [SimulatedKeyEventPacket], for a packet that simulates a key event from
///    the platform.
abstract class KeyEventPacket extends Diagnosticable {
  const KeyEventPacket();

  Duration get timestamp;

  KeyEventPacketType get eventType;

  LogicalKeyboardKey get logicalKey;

  PhysicalKeyboardKey get physicalKey;

  String get character;
}

/// Interprets raw key event data sent from the engine to the framework.
class PlatformKeyEventPacket extends KeyEventPacket {
  PlatformKeyEventPacket(this.data);

  PlatformKeyEventPacket.unpack(ByteData packet)
      : assert(packet != null),
        data = const StandardMessageCodec().decodeMessage(packet) as Map<int, dynamic> {
    assert(data != null, 'data packet not decoded properly');

    // Validate field index contract.
    assert(data.keys.where((int value) => !_kEventFields.contains(value)).isEmpty);
    assert(data[_kPayload] != null, 'Missing event payload data');
    assert((){
      return data[_kPayload].keys.where((int value) => !_kPayloadFields.contains(value)).isEmpty == true;
    }());

    // Validate field data contract.
    assert(timestamp != null);
    assert(eventType != null);
    assert(logicalKey != null);
    assert(physicalKey != null);
    assert(eventType == KeyEventPacketType.down || character == null, 'character only valid on down events');
  }

  final Map<int, dynamic> data;

  @override
  Duration get timestamp => _timestamp ??= Duration(microseconds: data[_kTimestamp] as int);
  Duration _timestamp;

  @override
  KeyEventPacketType get eventType {
    if (_keyEventPacketType == null) {
      final KeyEventPacketType type = KeyEventPacketType.values[data[_kEventType] as int];
      assert(() {
        switch (type) {
          case KeyEventPacketType.down:
          case KeyEventPacketType.up:
          case KeyEventPacketType.sync:
          case KeyEventPacketType.cancel:
            return true;
          default:
            return false;
        }
      }(), 'Unknown key event type $type');
      _keyEventPacketType = type;
    }
    return _keyEventPacketType;
  }
  KeyEventPacketType _keyEventPacketType;

  @override
  LogicalKeyboardKey get logicalKey {
    if (_logicalKey == null) {
      final Map<int, dynamic> keyData = data[_kPayload][_kLogicalKey] as Map<int, dynamic>;
      assert(keyData.keys.where((int value) => !_kLogicalKeyFields.contains(value)).isEmpty);
      final int keyId = keyData[_kLogicalKeyId] as int;
      LogicalKeyboardKey key = LogicalKeyboardKey.findKeyByKeyId(keyId);
      if (key == null) {
        final String keyLabel = keyData[_kLogicalKeyLabel] as String;
        key = LogicalKeyboardKey(
          keyId,
          keyLabel: keyLabel,
          debugName: kReleaseMode ? null : 'Key ${keyLabel.toUpperCase()}',
        );
      }
      _logicalKey = key;
    }
    return _logicalKey;
  }
  LogicalKeyboardKey _logicalKey;

  @override
  PhysicalKeyboardKey get physicalKey {
    if (_physicalKey == null) {
      final Map<int, dynamic> keyData = data[_kPayload][_kPhysicalKey] as Map<int, dynamic>;
      assert(keyData.keys.where((int value) => !_kPhysicalKeyFields.contains(value)).isEmpty);
      final int usbHidUsage = keyData[_kPhysicalKeyId] as int;
      PhysicalKeyboardKey key = PhysicalKeyboardKey.findKeyByCode(usbHidUsage);
      if (key == null) {
        final String keyLabel = keyData[_kPhysicalKeyLabel] as String;
        key = PhysicalKeyboardKey(
          usbHidUsage,
          debugName: kReleaseMode ? null : 'Key ${keyLabel.toUpperCase()}',
        );
      }
      _physicalKey = key;
    }
    return _physicalKey;
  }
  PhysicalKeyboardKey _physicalKey;

  @override
  String get character {
    // Character data is optional.
    return eventType == KeyEventPacketType.down ? data[_kPayload][_kCharacterProduced] as String: null;
  }
}

@pragma('vm:entry-point')
// ignore: unused_element
KeyEventResponse _dispatchKeyEvent(ByteData packet) {
  // Runs in the zone where the instance was created.
  if (identical(HardwareKeyboard.instance.dispatchKeyEventZone, Zone.current)) {
    return HardwareKeyboard.instance.handleKeyEvent(PlatformKeyEventPacket.unpack(packet));
  } else {
    return HardwareKeyboard.instance.dispatchKeyEventZone.runUnary<KeyEventResponse, PlatformKeyEventPacket>(
      HardwareKeyboard.instance.handleKeyEvent,
      PlatformKeyEventPacket.unpack(packet),
    );
  }
}

/// Used to simulate low level key events from the platform, generally used for
/// testing.
///
/// To simulate an event, create one of these and pass it to
/// [HardwareKeyboard.handleKeyEvent].
///
/// The [keysPressed] and [physicalKeysPressed] attributes should contain the state
/// as if the event had already happened, so, for instance, [keysPressed] should
/// contain [logicalKey] if this is a key down event, and not contain it if this
/// is a key up event.
///
/// If keysPressed and/or physicalKeysPressed is null on a key up or down, it
/// will use the current state of [HardwareKeyboard.keysPressed], and
/// [HardwareKeyboard.physicalKeysPressed], respectively, and do the right thing
/// with the supplied key values.
class SimulatedKeyEventPacket extends KeyEventPacket {
  const SimulatedKeyEventPacket({
    @required this.timestamp,
    @required this.eventType,
    @required this.logicalKey,
    @required this.physicalKey,
    this.character,
  })  : assert(timestamp != null),
        assert(eventType != null),
        assert(logicalKey != null, 'key up/down events must have a logical key'),
        assert(physicalKey != null, 'key up/down events must have a physical key'),
        assert(eventType == KeyEventPacketType.down || character == null, 'character only valid on down events');

  @override
  final Duration timestamp;

  @override
  final KeyEventPacketType eventType;

  @override
  final LogicalKeyboardKey logicalKey;

  @override
  final PhysicalKeyboardKey physicalKey;

  @override
  final String character; // Only used when event type is key down.
}
