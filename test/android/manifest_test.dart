import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app declares nothing Play Protect blocks in sideloaded apps', () {
    // Play Protect's fraud protection blocks installing an app from a browser
    // or file manager when it declares an accessibility service or a
    // notification listener (or reads SMS); Google Pay also refuses to pay
    // beside a downloaded accessibility service.
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    for (final blocked in [
      'BIND_ACCESSIBILITY_SERVICE',
      'BIND_NOTIFICATION_LISTENER_SERVICE',
      'RECEIVE_SMS',
      'READ_SMS',
    ]) {
      expect(manifest, isNot(contains(blocked)), reason: blocked);
    }
  });
}
