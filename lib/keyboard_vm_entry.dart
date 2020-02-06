// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';

import 'keyboard.dart'

@pragma('vm:entry-point')
// ignore: unused_element
bool _dispatchKeyEvent(ByteData packet) {
  // Runs in the zone where the instance was created.
  if (identical(HardwareKeyboard.instance._dispatchKeyEventZone, Zone.current)) {
    return HardwareKeyboard.instance._handleKeyEvent(_KeyEventPacket.unpack(packet));
  } else {
    return HardwareKeyboard.instance._dispatchKeyEventZone.runUnary<bool, _KeyEventPacket>(
      HardwareKeyboard.instance._handleKeyEvent,
      _KeyEventPacket.unpack(packet),
    );
  }
}

