import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;

class AudioUtil {
  AudioUtil._();

  static final _record = AudioRecorder();

  static Future<void> startRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    debugPrint('dir: ${dir}');

    // Check and request permission if needed
    if (await _record.hasPermission()) {
      // Start recording to file
      // await _record.start(const RecordConfig(), path: 'aFullPath/myFile.m4a');
      await _record.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          noiseSuppress: true,
          echoCancel: true,
          numChannels: 1,
        ),
        path: p.join(dir.path, 'myFile.wav'),
      );
      // ... or to stream
      // final stream = await _record.startStream(
      //   const RecordConfig(
      //     encoder: AudioEncoder.pcm16bits,
      //   ),
      // );
    }
  }

  static Future<void> stopRecording() async {
    // Stop recording...
    final path = await _record.stop();
    debugPrint('path: ${path}');
    // ... or cancel it (and implicitly remove file/blob).
    await _record.cancel();
    // As always, don't forget this one.
    // _record.dispose();
  }
}
