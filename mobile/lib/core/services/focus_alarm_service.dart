import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

class FocusAlarmService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playAlarm() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);

      debugPrint("PLAYING ALARM");
      await _player.setVolume(1.0);
      await _player.play(
        AssetSource('sounds/focus_complete.mp3'),
      );

      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(
          pattern: [500, 1000, 500, 1000, 500],
          repeat: 0,
        );
      }
    } catch (e, s) {
      debugPrint('Alarm error: $e');
      debugPrint('$s');
    }
  }

  static Future<void> stopAlarm() async {
    await _player.stop();
    await _player.release();

    if (await Vibration.hasVibrator()) {
      Vibration.cancel();
    }
  }
}
