import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flukely/screen/music_list_screen.dart';
import 'package:flukely/services/my_audio_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

AudioHandler? _audioHandler; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await _requestPermissions();

  _audioHandler ??= await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.flukely.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
    ),
  );

  runApp(MyApp(_audioHandler!));
}

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;

    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = deviceInfo.version.sdkInt;

    if (sdkInt >= 33) {
      // Android 13+ only needs audio permission for music/media files
      final audioStatus = await Permission.audio.request();
      if (!audioStatus.isGranted) {
        debugPrint("Audio permission not granted");
        // Optional: show dialog or exit
      }
    } else {
      // Android 12 and below
      final storageStatus = await Permission.storage.request();
      final manageStatus = await Permission.manageExternalStorage.request();
      if (!storageStatus.isGranted || !manageStatus.isGranted) {
        debugPrint("Storage permissions not granted");
        // Optional: show dialog or exit
      }
    }
  }


class MyApp extends StatelessWidget {
  final AudioHandler audioHandler;

  const MyApp(this.audioHandler, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MusicListScreen(audioHandler: audioHandler),
    );
  }
}
