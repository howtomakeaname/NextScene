import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/runtime_switch_policy.dart';

void main() {
  test('mobile runtimes can replace a parked game in process', () {
    expect(canReplaceParkedRuntime('android'), isTrue);
    expect(canReplaceParkedRuntime('ohos'), isTrue);
    expect(canReplaceParkedRuntime('ios'), isTrue);
  });

  test('unverified desktop runtimes keep the restart guard', () {
    expect(canReplaceParkedRuntime('macos'), isFalse);
    expect(canReplaceParkedRuntime('windows'), isFalse);
    expect(canReplaceParkedRuntime('linux'), isFalse);
  });
}
