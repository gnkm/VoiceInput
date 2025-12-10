import 'dart:typed_data';

class WavHeader {
  static Uint8List createWavHeader({
    required int dataLength,
    required int sampleRate,
    required int numChannels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final totalDataLen = dataLength + 36;

    final header = ByteData(44);

    // RIFF chunk descriptor
    _writeString(header, 0, 'RIFF');
    header.setUint32(4, totalDataLen, Endian.little);
    _writeString(header, 8, 'WAVE');

    // fmt sub-chunk
    _writeString(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data sub-chunk
    _writeString(header, 36, 'data');
    header.setUint32(40, dataLength, Endian.little);

    return header.buffer.asUint8List();
  }

  static void _writeString(ByteData data, int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }
}
