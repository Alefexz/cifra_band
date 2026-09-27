import 'package:flutter_test/flutter_test.dart';
import 'package:cifra_band/core/services/apk_artifact.dart';

void main() {
  final artifact = {
    'apkUrl': 'https://example.test/arm.apk',
    'apkSha256': 'a' * 64,
    'apkBytes': 25000000,
  };
  test(
    'selects only an architecture supported by the device in preference order',
    () {
      expect(
        ApkArtifact.select({'arm64-v8a': artifact}, ['armeabi-v7a']),
        isNull,
      );
      expect(
        ApkArtifact.select(
          {'arm64-v8a': artifact},
          ['arm64-v8a', 'armeabi-v7a'],
        )!.bytes,
        25000000,
      );
      expect(ApkArtifact.select({}, ['arm64-v8a']), isNull);
    },
  );
  test('invalid artifact metadata leaves universal fallback intact', () {
    for (final invalid in [
      {...artifact, 'apkUrl': 'http://example.test/app.apk'},
      {...artifact, 'apkUrl': 'https://user@example.test/app.apk'},
      {...artifact, 'apkSha256': 'bad'},
      {...artifact, 'apkBytes': -1},
      {...artifact, 'apkBytes': 999999999},
    ]) {
      expect(ApkArtifact.select({'arm64-v8a': invalid}, ['arm64-v8a']), isNull);
    }
  });
}
