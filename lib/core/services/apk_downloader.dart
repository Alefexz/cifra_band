import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class ApkDownloader {
  static Future<File> download({
    required http.Client client,
    required Uri uri,
    required File destination,
    required void Function(double) onProgress,
    void Function(int received, int? total, double bytesPerSecond)? onTransfer,
    String? expectedSha256,
    int? expectedBytes,
    Duration inactivity = const Duration(seconds: 30),
    Duration totalTimeout = const Duration(minutes: 20),
  }) async {
    if (uri.scheme != 'https') {
      client.close();
      throw const FormatException('O download precisa usar HTTPS.');
    }
    IOSink? sink;
    var complete = false;
    var preservePartial = false;
    final resumable =
        expectedBytes != null &&
        expectedBytes > 0 &&
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(expectedSha256 ?? '');
    final deadline = Timer(totalTimeout, client.close);
    final elapsed = Stopwatch()..start();
    try {
      var offset = resumable && await destination.exists()
          ? await destination.length()
          : 0;
      if (offset == expectedBytes && resumable) {
        final digest = await sha256.bind(destination.openRead()).first;
        if (digest.toString() == expectedSha256!.toLowerCase()) {
          complete = true;
          onProgress(1);
          return destination;
        }
        offset = 0;
      }
      if (expectedBytes != null && offset >= expectedBytes) offset = 0;
      final request = http.Request('GET', uri);
      request.headers['Accept-Encoding'] = 'identity';
      if (offset > 0) request.headers['Range'] = 'bytes=$offset-';
      final response = await client.send(request).timeout(inactivity);
      if (response.statusCode != 200 && response.statusCode != 206)
        throw HttpException('Download retornou HTTP ${response.statusCode}.');
      if (response.statusCode == 206) {
        final range = RegExp(
          r'^bytes (\d+)-(\d+)/(\d+)$',
        ).firstMatch(response.headers['content-range'] ?? '');
        if (!resumable ||
            offset == 0 ||
            range == null ||
            int.parse(range[1]!) != offset ||
            int.parse(range[2]!) != expectedBytes - 1 ||
            int.parse(range[3]!) != expectedBytes) {
          throw const FormatException('Resposta de retomada invalida.');
        }
      } else {
        // A server may ignore Range; in that case restart, never append.
        offset = 0;
      }
      if ((response.headers['content-type'] ?? '').contains('text/'))
        throw const FormatException('O link nao retornou um APK.');
      final total = expectedBytes ?? response.contentLength;
      var received = offset;
      var reportedAt = -250;
      final transferClock = Stopwatch()..start();
      sink = destination.openWrite(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      await for (final chunk in response.stream.timeout(inactivity)) {
        if (elapsed.elapsed > totalTimeout)
          throw TimeoutException('Tempo de download excedido.');
        received += chunk.length;
        if (received > 250 * 1024 * 1024 || (total != null && received > total))
          throw const FormatException('Tamanho de APK invalido.');
        sink.add(chunk);
        final ms = transferClock.elapsedMilliseconds;
        if (ms - reportedAt >= 250) {
          reportedAt = ms;
          onTransfer?.call(
            received,
            total,
            (received - offset) * 1000 / (ms > 0 ? ms : 1),
          );
          if (total != null && total > 0) {
            onProgress((received / total).clamp(0, 0.99));
          }
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (resumable && received < expectedBytes) {
        throw http.ClientException('Download interrompido. Tente retomar.');
      }
      if (received < 4 ||
          (total != null && total != received) ||
          (response.contentLength != null &&
              response.contentLength != received - offset))
        throw const FormatException('Download incompleto. Tente novamente.');
      final file = await destination.open();
      final header = await file.read(4);
      await file.close();
      if (header[0] != 0x50 ||
          header[1] != 0x4b ||
          header[2] != 3 ||
          header[3] != 4)
        throw const FormatException('Arquivo recebido nao e um APK.');
      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        final digest = await sha256.bind(destination.openRead()).first;
        if (digest.toString() != expectedSha256.toLowerCase())
          throw const FormatException(
            'A verificacao de integridade falhou. Baixe novamente.',
          );
      }
      complete = true;
      onProgress(1);
      return destination;
    } on TimeoutException {
      preservePartial = resumable;
      rethrow;
    } on SocketException {
      preservePartial = resumable;
      rethrow;
    } on http.ClientException {
      preservePartial = resumable;
      rethrow;
    } finally {
      deadline.cancel();
      client.close();
      await sink?.close();
      if (!complete && !preservePartial && await destination.exists()) {
        await destination.delete();
      }
    }
  }
}
