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
    String? expectedSha256,
    int? expectedBytes,
    Duration inactivity = const Duration(seconds: 30),
    Duration totalTimeout = const Duration(minutes: 8),
  }) async {
    if (uri.scheme != 'https') {
      client.close();
      throw const FormatException('O download precisa usar HTTPS.');
    }
    IOSink? sink;
    var complete = false;
    final deadline = Timer(totalTimeout, client.close);
    final elapsed = Stopwatch()..start();
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(inactivity);
      if (response.statusCode != 200)
        throw HttpException('Download retornou HTTP ${response.statusCode}.');
      if ((response.headers['content-type'] ?? '').contains('text/'))
        throw const FormatException('O link nao retornou um APK.');
      final total = expectedBytes ?? response.contentLength;
      var received = 0;
      sink = destination.openWrite();
      await for (final chunk in response.stream.timeout(inactivity)) {
        if (elapsed.elapsed > totalTimeout)
          throw TimeoutException('Tempo de download excedido.');
        received += chunk.length;
        if (received > 250 * 1024 * 1024 || (total != null && received > total))
          throw const FormatException('Tamanho de APK invalido.');
        sink.add(chunk);
        if (total != null && total > 0)
          onProgress((received / total).clamp(0, 0.99));
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (received < 4 ||
          (total != null && total != received) ||
          (response.contentLength != null &&
              response.contentLength != received))
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
    } finally {
      deadline.cancel();
      client.close();
      await sink?.close();
      if (!complete && await destination.exists()) await destination.delete();
    }
  }
}
