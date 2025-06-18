import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flukely/screen/music_full_screen.dart';
import 'package:flukely/services/my_audio_handler.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

class SongsPage extends StatefulWidget {
  final AudioHandler audioHandler;
  
  const SongsPage({super.key, required this.audioHandler});

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage>  with SingleTickerProviderStateMixin{
  late AnimationController _animationController;
  final _audioQuery = OnAudioQuery();
  List<SongModel> _songs = [];
  List<AudioSource> _audioSources = [];
  bool _hasPermission = false;
  late final MyAudioHandler _audioPlayer;
  final _searchController = TextEditingController();
  final String _searchQuery = '';
  bool? isSplashScreen;
  //timer
  Timer? _sleepTimer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = widget.audioHandler as MyAudioHandler;
    _animationController = AnimationController(
      duration: const Duration(seconds: 5), // Adjust rotation speed here
      vsync: this,
    )..repeat();
    initialise();
  }

  initialise()async{
    _checkAndRequestPermissions();
    Future.delayed(Duration(seconds: 3), (){
      setState(() {
        isSplashScreen = true;
      });
    });
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      if (!Platform.isAndroid) return;

      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;

      bool granted = false;

      if (sdkInt >= 33) {
        // Android 13+
        final audioStatus = await Permission.audio.request();
        granted = audioStatus.isGranted;
      } else if (sdkInt >= 30) {
        // Android 11-12
        final storageStatus = await Permission.storage.request();
        final manageStatus = await Permission.manageExternalStorage.request();
        granted = storageStatus.isGranted && manageStatus.isGranted;
      } else {
        // Android 10 and below
        final storageStatus = await Permission.storage.request();
        granted = storageStatus.isGranted;
      }

      if (granted) {
        setState(() => _hasPermission = true);
        await _loadSongs();
      } else {
        setState(() => _hasPermission = false);
      }
    } catch (e) {
      debugPrint("Permission error: $e");
      setState(() => _hasPermission = false);
    }
  }

  Future<void> _loadSongs() async {
    if (!_hasPermission) return;

    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.DISPLAY_NAME,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final validSongs = songs.where((song) =>
          song.isMusic! &&
          !song.data.contains('/Recordings') &&
          (song.data.endsWith('.mp3') || song.data.endsWith('.m4a'))).toList();

      setState(() => _songs = validSongs);

      _audioSources = validSongs.map((song) {
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

      await _audioPlayer.setAudioSource(
        // ignore: deprecated_member_use
        ConcatenatingAudioSource(children: _audioSources),
      );
    } catch (e) {
      debugPrint("Error loading songs: $e");
    }
  }

  Stream<MediaItem?> get currentMediaItem =>
      _audioPlayer.currentIndexStream.map((index) =>
          index != null ? (_audioSources[index] as UriAudioSource).tag as MediaItem : null);

  Stream<bool> get isPlaying => _audioPlayer.playingStream;

  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  List<SongModel> get _filteredSongs {
    if (_searchQuery.isEmpty) return _songs;
    return _songs.where((song) =>
        song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (song.artist?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
        (song.album?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)).toList();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This would contain your existing _buildBody() content
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.deepPurpleAccent.withValues(alpha: .1),
          Colors.purpleAccent.withValues(alpha: .1),
        ])
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          _buildBody(),
          _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.white70),
            const SizedBox(height: 20),
            const Text('Storage Permission Required', 
              style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 10),
            const Text('Please grant storage permissions to access your music',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => openAppSettings(),
              child: const Text('Grant Permission', 
                style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // const Icon(Icons.music_off, size: 50, color: Colors.white70),
            // const SizedBox(height: 20),
            // const Text('No Songs Found', 
            //   style: TextStyle(color: Colors.white, fontSize: 18)),
            // const SizedBox(height: 10),
            // const Text('Pull down to refresh or check your music files',
            //   style: TextStyle(color: Colors.white70, fontSize: 14)),
            // const SizedBox(height: 20),
            // ElevatedButton(
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.deepPurple,
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(20),
            //     ),
            //   ),
            //   onPressed: _loadSongs,
            //   child: const Text('Refresh', 
            //     style: TextStyle(color: Colors.white)),
            // ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      backgroundColor: Colors.deepPurple,
      color: Colors.white,
      onRefresh: _loadSongs,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 10, bottom: 80),
        itemCount: _filteredSongs.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey[800],
          height: 1,
          indent: 80,
        ),
        itemBuilder: (context, index) {
          final song = _filteredSongs[index];
          return InkWell(
            onTap: () async {
              final actualIndex = _songs.indexWhere((s) => s.id == song.id);
              if (actualIndex != -1) {
                await _playSong(actualIndex);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: RepaintBoundary(
                      child: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        artworkBorder: BorderRadius.circular(8),
                        nullArtworkWidget: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.deepPurpleAccent.withValues(alpha: .35),
                              Colors.purpleAccent.withValues(alpha: .35),
                            ])
                          ),
                          child: const Icon(Icons.music_note, color: Colors.white70),
                        ),
                        artworkWidth: 60,
                        artworkHeight: 60,
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
                          '${song.artist ?? 'Unknown Artist'} • ${song.album ?? 'Unknown Album'}',
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
                    stream: currentMediaItem,
                    builder: (context, snapshot) {
                      final currentItem = snapshot.data;
                      final isCurrent = currentItem != null && currentItem.id == song.id.toString();
                      return isCurrent
                          ? StreamBuilder<bool>(
                              stream: isPlaying,
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
    );
  }

  Widget _buildMiniPlayer() {
    return StreamBuilder<MediaItem?>(
      stream: currentMediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox();

        return Container(
          margin: EdgeInsets.fromLTRB(14,0,14, 88),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[900]!.withValues(alpha: 0.8),
                Colors.grey[800]!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
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
                  pageBuilder: (context, animation, secondaryAnimation) => MusicFullScreen(audioHandler: widget.audioHandler),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0); // Start from bottom
                    const end = Offset.zero; // End at top
                    const curve = Curves.easeInOut;

                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);

                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                  transitionDuration: Duration(milliseconds: 300), // Adjust duration as needed
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  _buildProgressBar(),
                  const SizedBox(height: 8),
                  _buildSongInfo(mediaItem),
                  _buildPlayerControls(),
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
        RotationTransition(
          turns: _animationController,
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
                    Colors.deepPurpleAccent.withValues(alpha: .35),
                    Colors.purpleAccent.withValues(alpha: .35),
                  ])
                ),
                child: const Icon(Icons.music_note, color: Colors.white70),
              ),
            ),
          ),
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

  Widget _buildPlayerControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          StreamBuilder<bool>(
            stream: _audioPlayer.shuffleModeEnabledStream,
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
                  _audioPlayer.setShuffleMode(
                    isShuffled 
                      ? AudioServiceShuffleMode.none 
                      : AudioServiceShuffleMode.all
                  );
                },
              );
            },
          ),

          //prev
          IconButton(
            icon: const Icon(Icons.skip_previous, size: 28),
            color: Colors.white,
            onPressed: _audioPlayer.hasPrevious ? () => _audioPlayer.skipToPrevious() : null,
          ),

          //play pause
          StreamBuilder<bool>(
            stream: isPlaying,
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
                    isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                  },
                ),
              );
            },
          ),

          // Next
          IconButton(
            icon: const Icon(Icons.skip_next, size: 28),
            color: Colors.white,
            onPressed: _audioPlayer.hasNext ? () => _audioPlayer.skipToNext() : null,
          ),

          // Repeat
          StreamBuilder<AudioServiceRepeatMode>(
            stream: _audioPlayer.repeatModeStream,
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
                  _audioPlayer.setRepeatMode(nextMode);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _audioPlayer.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        debugPrint('Position: ${position.inSeconds}'); // Debug output

        return StreamBuilder<Duration?>(
          stream: _audioPlayer.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            debugPrint('Duration: ${duration.inSeconds}'); // Debug output

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
                    onChangeStart: (value) {
                      // User started dragging
                      debugPrint('Slider drag started');
                    },
                    onChangeEnd: (value) {
                      // User stopped dragging
                      debugPrint('Slider drag ended');
                    },
                    onChanged: (value) {
                      // Only update during drag if you want real-time feedback
                      _audioPlayer.seek(Duration(milliseconds: value.toInt()));
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

  Future<void> _playSong(int index) async {
    try {
      await _audioPlayer.seekToIndex(index);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Error playing song: $e");
    }
  }
  
}