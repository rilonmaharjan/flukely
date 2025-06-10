import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flukely/services/my_audio_handler.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

class MusicPlayerScreen extends StatefulWidget {
  final AudioHandler audioHandler;
  const MusicPlayerScreen({super.key, required this.audioHandler});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final _audioQuery = OnAudioQuery();
  List<SongModel> _songs = [];
  List<AudioSource> _audioSources = [];
  bool _hasPermission = false;
  late final MyAudioHandler _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = widget.audioHandler as MyAudioHandler;
    _checkAndRequestPermissions();
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
            artUri: Uri.parse(song.uri!),
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSongs,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildMiniPlayer(),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return const Center(
        child: Text('Please grant storage permissions to access music'),
      );
    }

    if (_songs.isEmpty) {
      return const Center(
        child: Text('No songs found. Pull down to refresh.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSongs,
      child: ListView.builder(
        itemCount: _songs.length,
        itemBuilder: (context, index) {
          final song = _songs[index];
          return ListTile(
            leading: QueryArtworkWidget(
              id: song.id,
              type: ArtworkType.AUDIO,
              nullArtworkWidget: const Icon(Icons.music_note),
            ),
            title: Text(song.title),
            subtitle: Text('${song.artist ?? 'Unknown'} - ${song.album ?? 'Unknown'}'),
            onTap: () => _playSong(index),
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
          color: Colors.grey[900],
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSongInfo(mediaItem),
              _buildPlayerControls(),
              _buildProgressBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongInfo(MediaItem mediaItem) {
    return Row(
      children: [
        QueryArtworkWidget(
          id: int.parse(mediaItem.id),
          type: ArtworkType.AUDIO,
          nullArtworkWidget: const Icon(Icons.music_note, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                child: Marquee(
                  text: mediaItem.title,
                  style: const TextStyle(color: Colors.white),
                  blankSpace: 20,
                  velocity: 30,
                ),
              ),
              Text(
                mediaItem.artist ?? 'Unknown',
                style: const TextStyle(color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white),
          onPressed: (){ 
            if(_audioPlayer.hasPrevious){
              _audioPlayer.skipToPrevious();
            }
          }
        ),
        StreamBuilder<bool>(
          stream: isPlaying,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data ?? false;
            return IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
              onPressed: () {
                isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
              },
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white),
          onPressed: (){ 
            if(_audioPlayer.hasNext){
              _audioPlayer.skipToNext();
            }
          }
        ),
      ],
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
            return Slider(
              value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
              min: 0,
              max: duration.inMilliseconds.toDouble(),
              onChanged: (value) {
                _audioPlayer.seek(Duration(milliseconds: value.toInt()));
              },
              activeColor: Colors.white,
              inactiveColor: Colors.white30,
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
