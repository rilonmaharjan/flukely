import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flukely/services/my_audio_handler.dart';

class MusicFullScreen extends StatelessWidget {
  final AudioHandler audioHandler;
  const MusicFullScreen({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    final MyAudioHandler player = audioHandler as MyAudioHandler;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<MediaItem?>(
          stream: player.mediaItem,
          builder: (context, snapshot) {
            final item = snapshot.data;
            if (item == null) return const Center(child: CircularProgressIndicator());

            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Artwork
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: QueryArtworkWidget(
                      id: int.parse(item.id),
                      type: ArtworkType.AUDIO,
                      artworkFit: BoxFit.cover,
                      artworkBorder: BorderRadius.circular(16),
                      nullArtworkWidget: Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.music_note, size: 100, color: Colors.white),
                      ),
                    ),
                  ),
                ),

                // Song Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 24,
                        child: Marquee(
                          text: item.title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          blankSpace: 50,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(item.artist ?? 'Unknown',
                          style: const TextStyle(fontSize: 16, color: Colors.white70)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Controls
                _PlayerControls(player: player),

                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  final MyAudioHandler player;
  const _PlayerControls({required this.player});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, posSnapshot) {
        final position = posSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration?>(
          stream: player.durationStream,
          builder: (context, durSnapshot) {
            final duration = durSnapshot.data ?? Duration.zero;

            return Column(
              children: [
                // Slider with timer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      Slider(
                        value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                        min: 0,
                        max: duration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          player.seek(Duration(milliseconds: value.toInt()));
                        },
                        activeColor: Colors.white,
                        inactiveColor: Colors.white24,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Playback controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.white),
                      onPressed: () => player.skipToPrevious(),
                    ),
                    StreamBuilder<bool>(
                      stream: player.playingStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white, size: 40),
                          onPressed: () {
                            isPlaying ? player.pause() : player.play();
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      onPressed: () => player.skipToNext(),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

