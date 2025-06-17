import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flukely/screen/music_full_screen.dart';
import 'package:flukely/services/my_audio_handler.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

class MusicListScreen extends StatefulWidget {
  final AudioHandler audioHandler;
  const MusicListScreen({super.key, required this.audioHandler});

  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen> with SingleTickerProviderStateMixin{
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
  Duration _remainingTime = Duration.zero;
  bool _isTimerActive = false;

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
    await _checkAndRequestPermissions();
    Future.delayed(Duration(seconds: 3), (){
      setState(() {
        isSplashScreen = true;
      });
    });
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }

      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }

      if (await Permission.audio.isDenied) {
        await Permission.audio.request();
      }

      setState(() => _hasPermission = true);
      await _loadSongs();
    } catch (e) {
      debugPrint("Permission error: $e");
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

  void _startSleepTimer(Duration duration) {
    _cancelSleepTimer();
    setState(() {
      _remainingTime = duration;
      _isTimerActive = true;
    });
    
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Only update state when needed (last 10 seconds or minute changes)
      if (_remainingTime.inSeconds % 60 == 0 || _remainingTime.inSeconds <= 10) {
        if (mounted) {
          setState(() {
            _remainingTime -= const Duration(seconds: 1);
          });
        }
      } else {
        _remainingTime -= const Duration(seconds: 1);
      }
      
      if (_remainingTime.inSeconds <= 0) {
        _cancelSleepTimer();
        _audioPlayer.pause();
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    setState(() {
      _isTimerActive = false;
      _remainingTime = Duration.zero;
    });
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
    return isSplashScreen != true
      ? Scaffold(
        backgroundColor: Colors.grey[900],
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.deepPurpleAccent.withValues(alpha: .1),
              Colors.purpleAccent.withValues(alpha: .1),
            ])
          ),
          child: Center(
            child: RotationTransition(
              turns: _animationController,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:  Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.deepPurpleAccent.withValues(alpha: .35),
                      Colors.purpleAccent.withValues(alpha: .35),
                    ])
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white70, size: 80,),
                ),
              ),
            ),
          ),
        ),
      )
      : Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          backgroundColor: Colors.deepPurpleAccent.withValues(alpha: .1),
          elevation: 0,
          title: Text('Fukely', style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.grey[200]
          )),
          actions: [
            // Timer display and controls
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: MusicSearchDelegate(_songs, _playSong),
                    );
                  },
                ),
                const SizedBox(width: 4),
                TimerDisplay(
                  remainingTime: _remainingTime,
                  isActive: _isTimerActive,
                  onPressed: () {
                    if (_isTimerActive) {
                      _cancelSleepTimer();
                    } else {
                      _showTimerDialog();
                    }
                  },
                ),
                const SizedBox(width: 10)
              ],
            ),
          ],
        ),
        body: Container(
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
        ) 
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
              onPressed: _checkAndRequestPermissions,
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
            const Icon(Icons.music_off, size: 50, color: Colors.white70),
            const SizedBox(height: 20),
            const Text('No Songs Found', 
              style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 10),
            const Text('Pull down to refresh or check your music files',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _loadSongs,
              child: const Text('Refresh', 
                style: TextStyle(color: Colors.white)),
            ),
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
          margin: EdgeInsets.all(14),
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
      stream: positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: durationStream,
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
                    value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                    min: 0,
                    max: duration.inMilliseconds.toDouble(),
                    onChanged: (value) {
                      _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12,0,12,5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(format(position), style: TextStyle(color: Colors.grey[200], fontSize: 12)),
                      Text(format(duration), style: TextStyle(color: Colors.grey[200], fontSize: 12)),
                    ],
                  ),
                )
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
  
  void _showTimerDialog() {
    Duration selectedDuration = const Duration(minutes: 15); // Default value
    final TextEditingController controller = TextEditingController(text: "15");

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[850],
              title: const Text('Set Sleep Timer', 
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick Presets
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip('5 min', const Duration(minutes: 5)), 
                      _buildChip('15 min', const Duration(minutes: 15)),
                      _buildChip('30 min', const Duration(minutes: 30)),
                      _buildChip('1 hour', const Duration(hours: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Custom Time Picker
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          min: 1,
                          max: 120,
                          divisions: 119,
                          value: selectedDuration.inMinutes.toDouble(),
                          label: "${selectedDuration.inMinutes} min",
                          onChanged: (value) {
                            setState(() {
                              selectedDuration = Duration(minutes: value.toInt());
                              controller.text = value.toInt().toString();
                            });
                          },
                          activeColor: Colors.deepPurpleAccent,
                          inactiveColor: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  
                  // Manual Input
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Minutes',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(),
                      suffixText: 'min',
                      suffixStyle: TextStyle(color: Colors.white),
                    ),
                    style: TextStyle(color: Colors.white),
                    onChanged: (value) {
                      final minutes = int.tryParse(value) ?? 15;
                      setState(() {
                        selectedDuration = Duration(minutes: minutes.clamp(1, 120));
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel', 
                      style: TextStyle(color: Colors.deepPurpleAccent)),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('Set Timer', 
                      style: TextStyle(color: Colors.deepPurpleAccent)),
                  onPressed: () {
                    Navigator.pop(context);
                    _startSleepTimer(selectedDuration);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChip(String label, Duration duration) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: Colors.white)),
      selected: false,
      onSelected: (_) {
        Navigator.pop(context);
        _startSleepTimer(duration);
      },
      selectedColor: Colors.deepPurpleAccent,
      backgroundColor: Colors.grey[800],
      labelPadding: EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class MusicSearchDelegate extends SearchDelegate {
  final List<SongModel> songs;
  final Function(int) onSongSelected;

  MusicSearchDelegate(this.songs, this.onSongSelected);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = songs.where((song) =>
        song.title.toLowerCase().contains(query.toLowerCase()) ||
        (song.artist?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
        (song.album?.toLowerCase().contains(query.toLowerCase()) ?? false)).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.deepPurpleAccent.withValues(alpha: .1),
          Colors.purpleAccent.withValues(alpha: .1),
        ])
      ),
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final song = results[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                artworkBorder: BorderRadius.circular(8),
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
                artworkWidth: 50,
                artworkHeight: 50,
              ),
            ),
            title: Text(
              song.title,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${song.artist ?? 'Unknown Artist'} • ${song.album ?? 'Unknown Album'}',
              style: TextStyle(color: Colors.grey[400]),
            ),
            onTap: () {
              final originalIndex = songs.indexWhere((s) => s.id == song.id);
              if (originalIndex != -1) {
                onSongSelected(originalIndex);
                close(context, null);
              }
            },
          );
        },
      ),
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.deepPurpleAccent.withValues(alpha: .1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(color: Colors.white70),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white),
      ),
    );
  }
}

class TimerDisplay extends StatefulWidget {
  final Duration remainingTime;
  final bool isActive;
  final VoidCallback onPressed;
  
  const TimerDisplay({
    super.key,
    required this.remainingTime,
    required this.isActive,
    required this.onPressed,
  });

  @override
  State<TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends State<TimerDisplay> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // if (widget.isActive)
        //   Text(
        //     '${widget.remainingTime.inMinutes}:${(widget.remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
        //     style: const TextStyle(color: Colors.white),
        //   ),
        IconButton(
          icon: Icon(
            widget.isActive ? Icons.timer_off : Icons.timer,
            color: Colors.white,
          ),
          onPressed: widget.onPressed,
        ),
      ],
    );
  }
}