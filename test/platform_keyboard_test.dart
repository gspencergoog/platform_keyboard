import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:platform_keyboard/keyboard_vm_entry.dart';

import 'package:platform_keyboard/platform_keyboard.dart';

Matcher matchesKeyEvent(KeyEvent event) => MatchesKeyEvent(event);

class MatchesKeyEvent extends Matcher {
  MatchesKeyEvent(this.event);

  KeyEvent event;

  @override
  Description describe(Description description) {
    return description.add('Matches event ').addDescriptionOf(event);
  }

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! KeyEvent || item.runtimeType != event.runtimeType) {
      return false;
    }
    final KeyEvent keyEvent = item as KeyEvent;
    if (event.logicalKey == keyEvent.logicalKey &&
        event.physicalKey == keyEvent.physicalKey &&
        event.timestamp == keyEvent.timestamp) {
      if (keyEvent is KeyDownEvent) {
        return keyEvent.character == (event as KeyDownEvent).character;
      }
      return true;
    }
    return false;
  }

  @override
  Description describeMismatch(
      dynamic item, Description mismatchDescription, Map<dynamic, dynamic> matchState, bool verbose) {
    if (item is KeyEvent) {
      return super.describeMismatch(item, mismatchDescription, matchState, verbose);
    } else {
      return mismatchDescription.add('is not a key event');
    }
  }
}

void main() {
  testWidgets('Simulates keys', (WidgetTester tester) async {
    KeyEvent eventReceived;
    await tester.pumpWidget(HardwareKeyboardListener(
        onKey: (KeyEvent event) {
          eventReceived = event;
          return true;
        },
        child: Focus(autofocus: true, child: Container())));
    await tester.pump(); // wait for autofocus to take effect.

    HardwareKeyboard.instance.simulateKeyDownEvent(
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
      timestamp: Duration.zero,
      character: '\n',
    );
    expect(HardwareKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.enter), isTrue);
    expect(HardwareKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.enter), isTrue);
    expect(eventReceived, matchesKeyEvent(KeyDownEvent(
      timestamp: Duration.zero,
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
      character: '\n',
    )));
    eventReceived = null;

    HardwareKeyboard.instance.simulateKeyUpEvent(
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
      timestamp: Duration.zero,
    );
    expect(HardwareKeyboard.instance.keysPressed, isEmpty);
    expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
    expect(eventReceived, matchesKeyEvent(KeyUpEvent(
      timestamp: Duration.zero,
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
    )));
    eventReceived = null;

    HardwareKeyboard.instance.simulateKeySyncEvent(
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
      timestamp: Duration.zero,
    );
    expect(HardwareKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.enter), isTrue);
    expect(HardwareKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.enter), isTrue);
    expect(eventReceived, matchesKeyEvent(KeySyncEvent(
      timestamp: Duration.zero,
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
    )));
    eventReceived = null;

    HardwareKeyboard.instance.simulateKeyCancelEvent(
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
      timestamp: Duration.zero,
    );
    expect(HardwareKeyboard.instance.keysPressed, isEmpty);
    expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
    expect(eventReceived, matchesKeyEvent(KeyCancelEvent(
      timestamp: Duration.zero,
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
    )));
    eventReceived = null;
  });
  testWidgets('Down event KeyEventPacket can be decoded properly', (WidgetTester tester) async {
    KeyEvent eventReceived;
    await tester.pumpWidget(HardwareKeyboardListener(
        onKey: (KeyEvent event) {
          eventReceived = event;
          return true;
        },
        child: Focus(autofocus: true, child: Container())));
    await tester.pump(); // wait for autofocus to take effect.

    final Map<int, dynamic> syntheticPacket = <int, dynamic>{
      1: 10000,
      2: KeyEventPacketType.down.index,
      3: <int, dynamic> {
        100: <int, dynamic>{
          10000: 0x00100070028,
          20000: 'Enter',
        },
        200: <int, dynamic>{
          10000000: 0x00070028,
          20000000: 'Enter',
        },
        300: '\n',
      }
    };

    dispatchKeyEvent(const StandardMessageCodec().encodeMessage(syntheticPacket));
    expect(HardwareKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.enter), isTrue);
    expect(HardwareKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.enter), isTrue);
    expect(eventReceived, matchesKeyEvent(KeyDownEvent(
      timestamp: const Duration(milliseconds: 10),
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
      character: '\n',
    )));
  });
  testWidgets('Up event KeyEventPacket can be decoded properly', (WidgetTester tester) async {
    KeyEvent eventReceived;
    await tester.pumpWidget(HardwareKeyboardListener(
        onKey: (KeyEvent event) {
          eventReceived = event;
          return true;
        },
        child: Focus(autofocus: true, child: Container())));
    await tester.pump(); // wait for autofocus to take effect.

    final Map<int, dynamic> syntheticPacket = <int, dynamic>{
      1: 10000,
      2: KeyEventPacketType.up.index,
      3: <int, dynamic> {
        100: <int, dynamic>{
          10000: 0x00100070028,
          20000: 'Enter',
        },
        200: <int, dynamic>{
          10000000: 0x00070028,
          20000000: 'Enter',
        },
      }
    };

    // Sync an enter into the keysPressed.
    HardwareKeyboard.instance.simulateKeySyncEvent(
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
      timestamp: Duration.zero,
    );
    expect(HardwareKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.enter), isTrue);
    expect(HardwareKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.enter), isTrue);

    dispatchKeyEvent(const StandardMessageCodec().encodeMessage(syntheticPacket));
    expect(HardwareKeyboard.instance.keysPressed, isEmpty);
    expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
    expect(eventReceived, matchesKeyEvent(KeyUpEvent(
      timestamp: const Duration(milliseconds: 10),
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
    )));
  });
  testWidgets('Sync event KeyEventPacket can be decoded properly', (WidgetTester tester) async {
    KeyEvent eventReceived;
    await tester.pumpWidget(HardwareKeyboardListener(
        onKey: (KeyEvent event) {
          eventReceived = event;
          return true;
        },
        child: Focus(autofocus: true, child: Container())));
    await tester.pump(); // wait for autofocus to take effect.

    final Map<int, dynamic> syntheticPacket = <int, dynamic>{
      1: 10000,
      2: KeyEventPacketType.sync.index,
      3: <int, dynamic> {
        100: <int, dynamic>{
          10000: 0x00100070028,
          20000: 'Enter',
        },
        200: <int, dynamic>{
          10000000: 0x00070028,
          20000000: 'Enter',
        },
      }
    };

    dispatchKeyEvent(const StandardMessageCodec().encodeMessage(syntheticPacket));
    expect(HardwareKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.enter), isTrue);
    expect(HardwareKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.enter), isTrue);
    expect(eventReceived, matchesKeyEvent(KeySyncEvent(
      timestamp: const Duration(milliseconds: 10),
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
    )));
  });
  testWidgets('Cancel event KeyEventPacket can be decoded properly', (WidgetTester tester) async {
    KeyEvent eventReceived;
    await tester.pumpWidget(HardwareKeyboardListener(
        onKey: (KeyEvent event) {
          eventReceived = event;
          return true;
        },
        child: Focus(autofocus: true, child: Container())));
    await tester.pump(); // wait for autofocus to take effect.

    final Map<int, dynamic> syntheticPacket = <int, dynamic>{
      1: 10000,
      2: KeyEventPacketType.cancel.index,
      3: <int, dynamic> {
        100: <int, dynamic>{
          10000: 0x00100070028,
          20000: 'Enter',
        },
        200: <int, dynamic>{
          10000000: 0x00070028,
          20000000: 'Enter',
        },
      }
    };
    // Sync an enter into the keysPressed.
    HardwareKeyboard.instance.simulateKeySyncEvent(
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
      timestamp: Duration.zero,
    );
    expect(HardwareKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.enter), isTrue);
    expect(HardwareKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.enter), isTrue);

    dispatchKeyEvent(const StandardMessageCodec().encodeMessage(syntheticPacket));
    expect(HardwareKeyboard.instance.keysPressed, isEmpty);
    expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
    expect(eventReceived, matchesKeyEvent(KeyCancelEvent(
      timestamp: const Duration(milliseconds: 10),
      logicalKey: LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
    )));
  });
}
