import 'dart:async';

import 'package:audio_dataset_creater/constants/nums.dart';
import 'package:audio_dataset_creater/data/data.dart';
import 'package:audio_dataset_creater/utils/shared_pref_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:record/record.dart';

import 'platform/audio_recorder_platform.dart';

final currentCountProvider = StateProvider<int>((ref) {
  return 0;
});

final currentDataProvider = StateProvider<Map<String, dynamic>>((ref) {
  return {};
});

class Recorder extends ConsumerStatefulWidget {
  final void Function(String path) onStop;

  const Recorder({super.key, required this.onStop});

  @override
  ConsumerState<Recorder> createState() => _RecorderState();
}

class _RecorderState extends ConsumerState<Recorder> with AudioRecorderMixin {
  int _recordDuration = 0;
  Timer? _timer;
  late final AudioRecorder _audioRecorder;
  StreamSubscription<RecordState>? _recordSub;
  RecordState _recordState = RecordState.stop;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Amplitude? _amplitude;
  late TextEditingController currentCountController;

  //
  // Map<String, dynamic> currentData = {};
  // int val = 0;

  @override
  void initState() {
    currentCountController = TextEditingController();
    _audioRecorder = AudioRecorder();

    _recordSub = _audioRecorder.onStateChanged().listen((recordState) {
      _updateRecordState(recordState);
    });

    _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 300)).listen((amp) {
      setState(() => _amplitude = amp);
    });

    super.initState();

    //
    _init();
  }

  _init() async {
    int val = SharedPrefUtil.getVal() ?? 0;
    currentCountController.text = val.toString();

    afterBuildCreated(() {
      ref.read(currentCountProvider.notifier).state = val;
      ref.read(currentDataProvider.notifier).state = textData[val];
    });
  }

  Future<void> _start(Map<String, dynamic> currentData) async {
    try {
      if (await _audioRecorder.hasPermission()) {
        const encoder = AudioEncoder.wav;

        if (!await _isEncoderSupported(encoder)) {
          return;
        }

        final devs = await _audioRecorder.listInputDevices();
        debugPrint(devs.toString());

        const config = RecordConfig(
          encoder: encoder,
          numChannels: 1,
          sampleRate: 16000,
          noiseSuppress: true,
          echoCancel: true,
        );

        // Record to file
        await recordFile(_audioRecorder, config, currentData['id']);

        // Record to stream
        // await recordStream(_audioRecorder, config);

        _recordDuration = 0;

        _startTimer();
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> _stop() async {
    final path = await _audioRecorder.stop();

    if (path != null) {
      widget.onStop(path);
      int currentCount = ref.read(currentCountProvider);
      // Map<String, dynamic> currentData = ref.read(currentDataProvider);
      if (currentCount < textDataLength) {
        ref.read(currentCountProvider.notifier).state = currentCount + 1;
        ref.read(currentDataProvider.notifier).state = textData[currentCount + 1];
        currentCountController.text = (currentCount + 1).toString();
        SharedPrefUtil.set(currentCount + 1);
      }

      downloadWebData(path);
    }
  }

  Future<void> _pause() => _audioRecorder.pause();

  Future<void> _resume() => _audioRecorder.resume();

  void _updateRecordState(RecordState recordState) {
    setState(() => _recordState = recordState);

    switch (recordState) {
      case RecordState.pause:
        _timer?.cancel();
        break;
      case RecordState.record:
        _startTimer();
        break;
      case RecordState.stop:
        _timer?.cancel();
        _recordDuration = 0;
        break;
    }
  }

  Future<bool> _isEncoderSupported(AudioEncoder encoder) async {
    final isSupported = await _audioRecorder.isEncoderSupported(
      encoder,
    );

    if (!isSupported) {
      debugPrint('${encoder.name} is not supported on this platform.');
      debugPrint('Supported encoders are:');

      for (final e in AudioEncoder.values) {
        if (await _audioRecorder.isEncoderSupported(e)) {
          debugPrint('- ${encoder.name}');
        }
      }
    }

    return isSupported;
  }

  @override
  Widget build(BuildContext context) {
    int currentCount = ref.watch(currentCountProvider);
    Map<String, dynamic> currentData = ref.watch(currentDataProvider);

    return MaterialApp(
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ID: ${currentData['id'] == null ? '_' : '${currentData['id']}'}',
              style: const TextStyle(fontSize: 28, height: 1.8),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Text(
                '${currentData['count'] == null ? '0' : currentData['count'] + 1}. ${currentData['text']}',
                style: const TextStyle(fontSize: 28, height: 1.8),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                controller: currentCountController,
                onChanged: (value) {
                  if (value.trim().isNotEmpty) {
                    int intVal = int.parse(value);
                    if (intVal < textDataLength) {
                      ref.read(currentCountProvider.notifier).state = intVal;
                      ref.read(currentDataProvider.notifier).state = textData[intVal];
                    }
                  } else {
                    // currentCountController.text = currentCount.toString();
                  }
                },
              ),
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildRecordStopControl(currentData),
                const SizedBox(width: 20),
                _buildPauseResumeControl(),
                const SizedBox(width: 20),
                _buildText(currentCount),
              ],
            ),
            if (_amplitude != null) ...[
              const SizedBox(height: 40),
              Text('Current: ${_amplitude?.current ?? 0.0}'),
              Text('Max: ${_amplitude?.max ?? 0.0}'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Widget _buildRecordStopControl(Map<String, dynamic> currentData) {
    late Icon icon;
    late Color color;

    if (_recordState != RecordState.stop) {
      icon = const Icon(Icons.stop, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final theme = Theme.of(context);
      icon = Icon(Icons.mic, color: theme.primaryColor, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () {
            (_recordState != RecordState.stop) ? _stop() : _start(currentData);
          },
        ),
      ),
    );
  }

  Widget _buildPauseResumeControl() {
    if (_recordState == RecordState.stop) {
      return const SizedBox.shrink();
    }

    late Icon icon;
    late Color color;

    if (_recordState == RecordState.record) {
      icon = const Icon(Icons.pause, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final theme = Theme.of(context);
      icon = const Icon(Icons.play_arrow, color: Colors.red, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () {
            (_recordState == RecordState.pause) ? _resume() : _pause();
          },
        ),
      ),
    );
  }

  Widget _buildText(int currentCount) {
    if (_recordState != RecordState.stop) {
      return _buildTimer();
    }

    return Text("Waiting to record $currentCount");
  }

  Widget _buildTimer() {
    final String minutes = _formatNumber(_recordDuration ~/ 60);
    final String seconds = _formatNumber(_recordDuration % 60);

    return Text(
      '$minutes : $seconds',
      style: const TextStyle(color: Colors.red),
    );
  }

  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0$numberStr';
    }

    return numberStr;
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }
}
