class ApkArtifact {
  const ApkArtifact(this.url, this.sha256, this.bytes);
  final Uri url;
  final String sha256;
  final int bytes;

  static ApkArtifact? select(Map<String, dynamic> variants, List<String> abis) {
    for (final abi in abis) {
      if (!['arm64-v8a', 'armeabi-v7a', 'x86_64'].contains(abi)) continue;
      final data = variants[abi];
      if (data is! Map) continue;
      final url = Uri.tryParse('${data['apkUrl']}');
      final hash = '${data['apkSha256']}';
      final bytes = int.tryParse('${data['apkBytes']}');
      if (url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty ||
          !url.path.endsWith('.apk') ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash) ||
          bytes == null ||
          bytes <= 0 ||
          bytes > 250 * 1024 * 1024)
        continue;
      return ApkArtifact(url, hash.toLowerCase(), bytes);
    }
    return null;
  }
}
