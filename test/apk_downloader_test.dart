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
  http.BaseRequest? request;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    return response;
  }

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
  test('resumes a known artifact after interrupted transfer', () async {
    final file = File('${directory.path}/resume.apk');
    final hash = sha256.convert(bytes).toString();
    final first = DownloadClient(
      http.StreamedResponse(
        Stream.value(bytes.sublist(0, 4)),
        200,
        contentLength: bytes.length,
      ),
    );
    await expectLater(
      ApkDownloader.download(
        client: first,
        uri: Uri.parse('https://example.test/app.apk'),
        destination: file,
        onProgress: (_) {},
        expectedBytes: bytes.length,
        expectedSha256: hash,
      ),
      throwsA(isA<http.ClientException>()),
    );
    expect(await file.length(), 4);
    final second = DownloadClient(
      http.StreamedResponse(
        Stream.value(bytes.sublist(4)),
        206,
        contentLength: 4,
        headers: {'content-range': 'bytes 4-7/8'},
      ),
    );
    await ApkDownloader.download(
      client: second,
      uri: Uri.parse('https://example.test/app.apk'),
      destination: file,
      onProgress: (_) {},
      expectedBytes: bytes.length,
      expectedSha256: hash,
    );
    expect(second.request!.headers['Range'], 'bytes=4-');
    expect(await file.readAsBytes(), bytes);
  });
  test(
    'server ignoring Range replaces partial file instead of appending',
    () async {
      final file = File('${directory.path}/restart.apk');
      await file.writeAsBytes(bytes.sublist(0, 4));
      final client = DownloadClient(
        http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        ),
      );
      await ApkDownloader.download(
        client: client,
        uri: Uri.parse('https://example.test/app.apk'),
        destination: file,
        onProgress: (_) {},
        expectedBytes: bytes.length,
        expectedSha256: sha256.convert(bytes).toString(),
      );
      expect(await file.readAsBytes(), bytes);
    },
  );
  test('invalid resume range is discarded', () async {
    final file = File('${directory.path}/bad-range.apk');
    await file.writeAsBytes(bytes.sublist(0, 4));
    final client = DownloadClient(
      http.StreamedResponse(
        Stream.value(bytes.sublist(4)),
        206,
        headers: {'content-range': 'bytes 2-7/8'},
      ),
    );
    await expectLater(
      ApkDownloader.download(
        client: client,
        uri: Uri.parse('https://example.test/app.apk'),
        destination: file,
        onProgress: (_) {},
        expectedBytes: bytes.length,
        expectedSha256: sha256.convert(bytes).toString(),
      ),
      throwsFormatException,
    );
    expect(await file.exists(), false);
  });
  test('verified complete file avoids a second network download', () async {
    final file = File('${directory.path}/ready.apk');
    await file.writeAsBytes(bytes);
    final client = DownloadClient(http.StreamedResponse(Stream.value([]), 503));
    await ApkDownloader.download(
      client: client,
      uri: Uri.parse('https://example.test/app.apk'),
      destination: file,
      onProgress: (_) {},
      expectedBytes: bytes.length,
      expectedSha256: sha256.convert(bytes).toString(),
    );
    expect(client.request, isNull);
    expect(client.closed, true);
  });
  test(
    'progress callbacks are throttled but finish only after verification',
    () async {
      final data = [...bytes, ...List.filled(10000, 0)];
      var calls = 0;
      var finalProgress = 0.0;
      await ApkDownloader.download(
        client: DownloadClient(
          http.StreamedResponse(
            Stream.fromIterable(data.map((b) => [b])),
            200,
            contentLength: data.length,
          ),
        ),
        uri: Uri.parse('https://example.test/app.apk'),
        destination: File('${directory.path}/chunks.apk'),
        expectedSha256: sha256.convert(data).toString(),
        onProgress: (value) {
          calls++;
          finalProgress = value;
        },
      );
      expect(calls, lessThan(100));
      expect(finalProgress, 1);
    },
  );
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
