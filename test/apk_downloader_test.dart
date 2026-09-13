import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:cifra_band/core/services/apk_downloader.dart';

class DownloadClient extends http.BaseClient {
  DownloadClient(this.response);
  final http.StreamedResponse response;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      response;
  @override
  void close() {
    closed = true;
  }
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cifra-apk-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  final bytes = [0x50, 0x4b, 3, 4, 10, 20, 30, 40];
  test(
    'validates length and hash and closes client on successful APK',
    () async {
      final client = DownloadClient(
        http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        ),
      );
      final file = await ApkDownloader.download(
        client: client,
        uri: Uri.parse('https://example.test/app.apk'),
        destination: File('${directory.path}/app.apk'),
        onProgress: (_) {},
        expectedSha256: sha256.convert(bytes).toString(),
        expectedBytes: bytes.length,
      );
      expect(await file.readAsBytes(), bytes);
      expect(client.closed, true);
    },
  );
  for (final problem in ['truncated', 'hash', 'html', 'http']) {
    test('rejects $problem and cleans partial APK and client', () async {
      final client = DownloadClient(
        http.StreamedResponse(
          Stream.value(bytes),
          problem == 'http' ? 503 : 200,
          contentLength: problem == 'truncated' ? 100 : bytes.length,
          headers: {
            'content-type': problem == 'html'
                ? 'text/html'
                : 'application/octet-stream',
          },
        ),
      );
      final file = File('${directory.path}/app.apk');
      await expectLater(
        ApkDownloader.download(
          client: client,
          uri: Uri.parse('https://example.test/app.apk'),
          destination: file,
          onProgress: (_) {},
          expectedSha256: problem == 'hash' ? 'bad-hash' : null,
        ),
        throwsA(isA<Exception>()),
      );
      expect(client.closed, true);
      expect(await file.exists(), false);
    });
  }
  test('stalled stream times out and removes partial file', () async {
    final stream = StreamController<List<int>>();
    final client = DownloadClient(http.StreamedResponse(stream.stream, 200));
    final file = File('${directory.path}/app.apk');
    await expectLater(
      ApkDownloader.download(
        client: client,
        uri: Uri.parse('https://example.test/app.apk'),
        destination: file,
        onProgress: (_) {},
        inactivity: const Duration(milliseconds: 20),
      ),
      throwsA(isA<TimeoutException>()),
    );
    await stream.close();
    expect(client.closed, true);
    expect(await file.exists(), false);
  });
}
