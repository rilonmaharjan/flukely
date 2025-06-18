import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flukely/screen/album_artist_screen.dart';
import 'package:flukely/screen/songs_list_screen.dart';
import 'package:flukely/services/my_audio_handler.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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
  bool? isSplashScreen;
  //timer
  Timer? _sleepTimer;
  Duration _remainingTime = Duration.zero;
  bool _isTimerActive = false;

  int _currentIndex = 1;
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _audioPlayer = widget.audioHandler as MyAudioHandler;
    _animationController = AnimationController(
      duration: const Duration(seconds: 5), // Adjust rotation speed here
      vsync: this,
    )..repeat();
    // Initialize pages
    _pages.addAll([
      AlbumArtistsPage(audioHandler: widget.audioHandler), // We'll extract the songs list to a separate widget
      SongsPage(audioHandler: widget.audioHandler), // We'll extract the songs list to a separate widget
      AlbumArtistsPage(audioHandler: widget.audioHandler), // We'll extract the songs list to a separate widget
      // ArtistsPage(audioHandler: widget.audioHandler),
      // AlbumsPage(audioHandler: widget.audioHandler),
    ]);
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
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            _pages[_currentIndex], // Show current page based on index
            _buildBottomNavigationBar()
          ],
        ) 
      );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[800]!.withValues(alpha:0.7),
            Colors.grey[800]!.withValues(alpha:1),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color.fromARGB(255, 240, 77, 255),
          unselectedItemColor: Colors.grey[100],
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          iconSize: 28,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.album),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.music_note),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '',
            ),
          ],
        ),
      ),
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