import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flukely/services/my_audio_handler.dart';

class MusicFullScreen extends StatefulWidget {
  final AudioHandler audioHandler;
  const MusicFullScreen({super.key, required this.audioHandler});

  @override
  State<MusicFullScreen> createState() => _MusicFullScreenState();
}

class _MusicFullScreenState extends State<MusicFullScreen> {
  @override
  Widget build(BuildContext context) {
    final MyAudioHandler player = widget.audioHandler as MyAudioHandler;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: StreamBuilder<MediaItem?>(
        stream: player.mediaItem,
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.deepPurpleAccent),
              ),
            );
          }
      
          return Stack(
            children: [
              // Background artwork blur effect
              Positioned.fill(
                child: Stack(
                  children: [
                    QueryArtworkWidget(
                      id: int.parse(item.id),
                      type: ArtworkType.AUDIO,
                      artworkFit: BoxFit.cover,
                      artworkBorder: BorderRadius.circular(0),
                      nullArtworkWidget: Container(
                        color: Colors.grey[900],
                      ),
                      artworkWidth: MediaQuery.of(context).size.width,
                      artworkHeight: MediaQuery.of(context).size.height,
                    ),
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.deepPurpleAccent.withValues(alpha: .15),
                              Colors.purpleAccent.withValues(alpha: .15),
                            ])
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.black.withValues(alpha: .15),
                              Colors.black.withValues(alpha: .15),
                            ])
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App bar with back button
                  SizedBox(height: 30,),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
      
                  // Artwork with vinyl record effect
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 356,
                        height: 330,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: QueryArtworkWidget(
                            id: int.parse(item.id),
                            type: ArtworkType.AUDIO,
                            artworkFit: BoxFit.cover,
                            artworkQuality: FilterQuality.high,
                            artworkBorder: BorderRadius.circular(8),
                            nullArtworkWidget: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.deepPurpleAccent.withValues(alpha: .35),
                                  Colors.purpleAccent.withValues(alpha: .35),
                                ])
                              ),
                              child: const Icon(
                                Icons.music_note,
                                size: 150,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
      
                  // Song info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 28,
                          child: Marquee(
                            text: item.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            blankSpace: 50,
                            velocity: 30,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.artist == "<unknown>" ? "" : item.artist ?? 'Unknown Artist',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.album ?? 'Unknown Album',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[200],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
      
                  // Controls
                  _PlayerControls(player: player),
      
                  const SizedBox(height: 20),
                ],
              ),
            ],
          );
        },
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
    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, posSnapshot) {
              final position = posSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration?>(
                stream: player.durationStream,
                builder: (context, durSnapshot) {
                  final duration = durSnapshot.data ?? Duration.zero;
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Colors.deepPurpleAccent,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: position.inMilliseconds.toDouble().clamp(
                                0.0,
                                duration.inMilliseconds.toDouble(),
                              ),
                          min: 0,
                          max: duration.inMilliseconds.toDouble(),
                          onChanged: (value) {
                            player.seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Main controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Shuffle
              StreamBuilder<bool>(
                stream: player.shuffleModeEnabledStream,
                builder: (context, snapshot) {
                  final isShuffled = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: isShuffled
                          ? Colors.deepPurpleAccent
                          : Colors.white70,
                    ),
                    onPressed: () {
                      player.setShuffleMode(
                        isShuffled 
                          ? AudioServiceShuffleMode.none 
                          : AudioServiceShuffleMode.all
                      );
                    },
                  );
                },
              ),

              // Previous
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32),
                color: Colors.white,
                onPressed: player.hasPrevious ? () => player.skipToPrevious() : null,
              ),

              // Play/Pause
              StreamBuilder<bool>(
                stream: player.playingStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurpleAccent,
                          Colors.purpleAccent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 36,
                      ),
                      color: Colors.white,
                      onPressed: () {
                        isPlaying ? player.pause() : player.play();
                      },
                    ),
                  );
                },
              ),

              // Next
              IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                color: Colors.white,
                onPressed: player.hasNext ? () => player.skipToNext() : null,
              ),

              // Repeat
              StreamBuilder<AudioServiceRepeatMode>(
                stream: player.repeatModeStream,
                builder: (context, snapshot) {
                  final repeatMode = snapshot.data ?? AudioServiceRepeatMode.none;
                  return IconButton(
                    icon: Icon(
                      repeatMode == AudioServiceRepeatMode.one
                          ? Icons.repeat_one
                          : Icons.repeat,
                      color: repeatMode != AudioServiceRepeatMode.none
                          ? Colors.deepPurpleAccent
                          : Colors.white70,
                    ),
                    onPressed: () {
                      final nextMode = repeatMode == AudioServiceRepeatMode.none
                          ? AudioServiceRepeatMode.all
                          : repeatMode == AudioServiceRepeatMode.all
                              ? AudioServiceRepeatMode.one
                              : AudioServiceRepeatMode.none;
                      player.setRepeatMode(nextMode);
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
      ],
    );
  }
}