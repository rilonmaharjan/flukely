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

  @override
  void dispose() {
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
        body: Center(
          child: RotationTransition(
            turns: _animationController,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child:  Container(
                width: 150,
                height: 150,
                color: Colors.grey[800],
                child: const Icon(Icons.music_note, color: Colors.white70, size: 80,),
              ),
            ),
          ),
        ),
      )
      : Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Fukely', style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.grey[200]
          )),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: MusicSearchDelegate(_songs, _playSong),
                );
              },
            ),
            SizedBox(width: 10,)
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildMiniPlayer(),
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
                    borderRadius: BorderRadius.circular(100),
                    child: QueryArtworkWidget(
                      id: song.id,
                      type: ArtworkType.AUDIO,
                      nullArtworkWidget: Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[800],
                        child: const Icon(Icons.music_note, color: Colors.white70),
                      ),
                      artworkWidth: 60,
                      artworkHeight: 60,
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[850]!.withValues(alpha: 0.9),
                Colors.grey[900]!,
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MusicFullScreen(audioHandler: widget.audioHandler),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                color: Colors.grey[800],
                child: const Icon(Icons.music_note, color: Colors.white70),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
      ],
    );
  }

  Widget _buildPlayerControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous, size: 28),
            color: Colors.white,
            onPressed: () {
              if (_audioPlayer.hasPrevious) {
                _audioPlayer.skipToPrevious();
              }
            },
          ),
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
          IconButton(
            icon: const Icon(Icons.skip_next, size: 28),
            color: Colors.white,
            onPressed: () {
              if (_audioPlayer.hasNext) {
                _audioPlayer.skipToNext();
              }
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

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final song = results[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: QueryArtworkWidget(
              id: song.id,
              type: ArtworkType.AUDIO,
              nullArtworkWidget: Container(
                width: 50,
                height: 50,
                color: Colors.grey[800],
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
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
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