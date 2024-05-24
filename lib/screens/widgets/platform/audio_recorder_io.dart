import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

mixin AudioRecorderMixin {
  Future<void> recordFile(AudioRecorder recorder, RecordConfig config, String id) async {
    final path = await _getPath(id);
    await recorder.start(config, path: path);
  }

  Future<void> recordStream(AudioRecorder recorder, RecordConfig config, String id) async {
    final path = await _getPath(id);
    final file = File(path);
    final stream = await recorder.startStream(config);
    stream.listen(
      (data) {
        debugPrint('${recorder.convertBytesToInt16(Uint8List.fromList(data))}');
        file.writeAsBytesSync(data, mode: FileMode.append);
      },
      onDone: () {
        debugPrint('End of stream. File written to $path.');
      },
    );
  }

  void downloadWebData(String path) {}

  Future<String> _getPath(String id) async {
    final dir = await createCustomFolder('AudioDataset');
    return p.join(
      dir.path,
      '${id}.wav',
      // 'audio_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
  }

  Future<Directory> createCustomFolder(String folderName) async {
    bool isPermissionAccepted = false;
    while (!isPermissionAccepted) {
      var status = await Permission.storage.request();
      if (status.isDenied) {
        // We haven't asked for permission yet or the permission has been denied before, but not permanently.
      } else {
        isPermissionAccepted = true;
      }
    }

    // final Directory customDir = Directory('/storage/emulated/0/${folderName}');
    final appDir = await getApplicationDocumentsDirectory();
    Directory customDir = Directory(p.join(appDir.path, folderName));

    if (await customDir.exists()) {
      // The folder already exists
      return customDir;
    } else {
      // Create the folder
      Directory createdDir = await customDir.create(recursive: true);
      return createdDir;
    }
  }

  //
}
