import 'dart:typed_data';

class WavHeader {
  /// Adds a standard WAV header to raw PCM data
  static Uint8List addHeader(List<double> samples) {
    int sampleRate = 16000;
    int channels = 1;
    int fileSize = (samples.length * 2) + 36; 

    final header = ByteData(44);
    
    _writeString(header, 0, 'RIFF');
    header.setUint32(4, fileSize, Endian.little);
    _writeString(header, 8, 'WAVE');
    _writeString(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little); 
    header.setUint16(20, 1, Endian.little); 
    header.setUint16(22, channels, Endian.little); 
    header.setUint32(24, sampleRate, Endian.little); 
    header.setUint32(28, sampleRate * 2 * channels, Endian.little); 
    header.setUint16(32, 2, Endian.little); 
    header.setUint16(34, 16, Endian.little); 
    _writeString(header, 36, 'data');
    header.setUint32(40, samples.length * 2, Endian.little);

    final pcmBytes = Uint8List(samples.length * 2);
    final view = ByteData.view(pcmBytes.buffer);
    
    for (int i = 0; i < samples.length; i++) {
      // Convert float (-1.0 to 1.0) to 16-bit int
      int val = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      view.setInt16(i * 2, val, Endian.little);
    }

    final wav = BytesBuilder();
    wav.add(header.buffer.asUint8List());
    wav.add(pcmBytes);
    return wav.toBytes();
  }

  static void _writeString(ByteData data, int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }
}