import 'package:audio_service/audio_service.dart';
import 'package:flukely/screen/music_list_screen.dart';
import 'package:flukely/services/my_audio_handler.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

AudioHandler? _audioHandler; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _requestPermissions();

  // Check if already initialized
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
  await [
    Permission.storage,
    Permission.manageExternalStorage,
    Permission.audio,
  ].request();
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
