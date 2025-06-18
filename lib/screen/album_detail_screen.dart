import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flukely/services/my_audio_handler.dart';
import 'package:flukely/screen/music_full_screen.dart';

class AlbumDetailPage extends StatefulWidget {
  final AlbumModel album;
  final AudioHandler audioHandler;
  
  const AlbumDetailPage({
    super.key,
    required this.album,
    required this.audioHandler,
  });

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> with SingleTickerProviderStateMixin {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  late AnimationController _animationController;
  List<SongModel> _songs = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _playAlbumSongs(List<SongModel> songs, int index) async {
    try {
      final myAudioHandler = widget.audioHandler as MyAudioHandler;
      
      final audioSources = songs.map((song) {
        return AudioSource.uri(
          Uri.parse(song.uri!),
          tag: MediaItem(
            id: song.id.toString(),
            title: song.title,
            artist: song.artist,
            album: song.album,
            artUri: Uri.file(song.data),
          ),
        );
      }).toList();

      // Create concatenated source manually
      await myAudioHandler.setAudioSource(
        ConcatenatingAudioSource(children: audioSources),
      );
      
      // Jump to the specific index
      await myAudioHandler.seekToIndex(index);
      await myAudioHandler.play();
    } catch (e) {
      debugPrint("Error playing song: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(widget.album.album),
        backgroundColor: Colors.deepPurpleAccent.withValues(alpha:.1),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<SongModel>>(
        future: _audioQuery.queryAudiosFrom(
          AudiosFromType.ALBUM_ID,
          widget.album.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
          }
          
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_off, size: 50, color: Colors.white70),
                  const SizedBox(height: 20),
                  const Text('No Songs Found', 
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            );
          }
          
          _songs = snapshot.data!;
          final audioHandler = widget.audioHandler as MyAudioHandler;
          
          return Column(
            children: [
              // Album header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.deepPurpleAccent.withValues(alpha:.1),
                    Colors.purpleAccent.withValues(alpha:.1),
                  ])
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: QueryArtworkWidget(
                        id: widget.album.id,
                        type: ArtworkType.ALBUM,
                        artworkWidth: 120,
                        artworkHeight: 120,
                        artworkBorder: BorderRadius.circular(12),
                        nullArtworkWidget: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.deepPurpleAccent.withValues(alpha:.35),
                              Colors.purpleAccent.withValues(alpha:.35),
                            ])
                          ),
                          child: const Icon(Icons.album, size: 50, color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.album.album,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.album.artist ?? 'Unknown Artist',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_songs.length} ${_songs.length == 1 ? 'song' : 'songs'}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Song list
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.deepPurpleAccent.withValues(alpha:.1),
                      Colors.purpleAccent.withValues(alpha:.1),
                    ])
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _songs.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.grey[800],
                      height: 1,
                      indent: 80,
                    ),
                    itemBuilder: (context, index) {
                      final song = _songs[index];
                      return InkWell(
                        onTap: () async {
                          await _playAlbumSongs(_songs, index);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              // Track number
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      song.artist ?? 'Unknown Artist',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              StreamBuilder<MediaItem?>(
                                stream: audioHandler.currentMediaItem,
                                builder: (context, snapshot) {
                                  final currentItem = snapshot.data;
                                  final isCurrent = currentItem != null && currentItem.id == song.id.toString();
                                  return isCurrent
                                      ? StreamBuilder<bool>(
                                          stream: audioHandler.playingStream,
                                          builder: (context, snapshot) {
                                            final isPlaying = snapshot.data ?? false;
                                            return Icon(
                                              isPlaying ? Icons.equalizer : Icons.pause,
                                              color: Colors.deepPurpleAccent,
                                            );
                                          },
                                        )
                                      : const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white70,
                                        );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildMiniPlayer(),
    );
  }

  Widget _buildMiniPlayer() {
    final audioHandler = widget.audioHandler as MyAudioHandler;
    
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.currentMediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox();

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[900]!.withValues(alpha:0.8),
                Colors.grey[800]!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => 
                    MusicFullScreen(audioHandler: widget.audioHandler),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;

                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);

                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  _buildProgressBar(audioHandler),
                  const SizedBox(height: 8),
                  _buildSongInfo(mediaItem),
                  _buildPlayerControls(audioHandler),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongInfo(MediaItem mediaItem) {
    return Row(
      children: [
        StreamBuilder<bool>(
          stream: (widget.audioHandler as MyAudioHandler).playingStream,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data ?? false;
            return RotationTransition(
              turns: isPlaying ? _animationController : const AlwaysStoppedAnimation(0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: QueryArtworkWidget(
                  id: int.parse(mediaItem.id),
                  type: ArtworkType.AUDIO,
                  artworkWidth: 50,
                  artworkHeight: 50,
                  nullArtworkWidget: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.deepPurpleAccent.withValues(alpha:.35),
                        Colors.purpleAccent.withValues(alpha:.35),
                      ])
                    ),
                    child: const Icon(Icons.music_note, color: Colors.white70),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                child: Marquee(
                  text: mediaItem.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  blankSpace: 20,
                  velocity: 30,
                ),
              ),
              Text(
                mediaItem.artist ?? 'Unknown Artist',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildPlayerControls(MyAudioHandler audioHandler) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          StreamBuilder<bool>(
            stream: audioHandler.shuffleModeEnabledStream,
            builder: (context, snapshot) {
              final isShuffled = snapshot.data ?? false;
              return IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: isShuffled ? Colors.deepPurpleAccent : Colors.white70,
                ),
                onPressed: () {
                  audioHandler.setShuffleMode(
                    isShuffled 
                      ? AudioServiceShuffleMode.none 
                      : AudioServiceShuffleMode.all
                  );
                },
              );
            },
          ),

          // Previous
          StreamBuilder<bool>(
            stream: audioHandler.playbackState.map((state) => state.controls.contains(MediaControl.skipToPrevious)),
            builder: (context, snapshot) {
              final hasPrevious = snapshot.data ?? false;
              return IconButton(
                icon: const Icon(Icons.skip_previous, size: 28),
                color: Colors.white,
                onPressed: hasPrevious ? () => audioHandler.skipToPrevious() : null,
              );
            },
          ),

          // Play/Pause
          StreamBuilder<bool>(
            stream: audioHandler.playingStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.deepPurpleAccent, Colors.purpleAccent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha:0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 32,
                  ),
                  color: Colors.white,
                  onPressed: () {
                    isPlaying ? audioHandler.pause() : audioHandler.play();
                  },
                ),
              );
            },
          ),

          // Next
          StreamBuilder<bool>(
            stream: audioHandler.playbackState.map((state) => state.controls.contains(MediaControl.skipToNext)),
            builder: (context, snapshot) {
              final hasNext = snapshot.data ?? false;
              return IconButton(
                icon: const Icon(Icons.skip_next, size: 28),
                color: Colors.white,
                onPressed: hasNext ? () => audioHandler.skipToNext() : null,
              );
            },
          ),

          // Repeat
          StreamBuilder<AudioServiceRepeatMode>(
            stream: audioHandler.repeatModeStream,
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
                  audioHandler.setRepeatMode(nextMode);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(MyAudioHandler audioHandler) {
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: audioHandler.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;

            String format(Duration d) {
              final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
              final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
              return '$minutes:$seconds';
            }

            return Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Colors.deepPurpleAccent,
                    inactiveTrackColor: Colors.grey[700],
                    thumbColor: Colors.deepPurpleAccent,
                  ),
                  child: Slider(
                    value: position.inMilliseconds.toDouble().clamp(
                      0.0,
                      duration.inMilliseconds.toDouble(),
                    ),
                    min: 0,
                    max: duration.inMilliseconds.toDouble(),
                    onChangeStart: (value) => audioHandler.customAction('pause'),
                    onChangeEnd: (value) => audioHandler.customAction('play'),
                    onChanged: (value) {
                      audioHandler.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        format(position),
                        style: TextStyle(color: Colors.grey[200], fontSize: 12),
                      ),
                      Text(
                        format(duration),
                        style: TextStyle(color: Colors.grey[200], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}