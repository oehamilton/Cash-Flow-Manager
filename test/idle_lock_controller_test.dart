import 'package:cash_flow_manager/features/settings/idle_lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timeout of zero never arms a timer', () {
    var fired = 0;
    final controller = IdleLockController(onIdle: () => fired++);
    controller.updateTimeout(0);
    controller.arm();
    controller.noteActivity();
    expect(fired, 0);
    expect(controller.timeoutMinutes, 0);
    controller.dispose();
  });

  test('updateTimeout stores minutes and disarm clears arming', () {
    var fired = 0;
    final controller = IdleLockController(
      onIdle: () => fired++,
      unit: const Duration(hours: 1),
    );
    controller.updateTimeout(15);
    controller.arm();
    expect(controller.timeoutMinutes, 15);
    controller.disarm();
    controller.noteActivity();
    expect(fired, 0);
    controller.dispose();
  });
}
