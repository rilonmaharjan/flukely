// ignore_for_file: deprecated_member_use

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // Add these getters for UI
  Stream<bool> get shuffleModeEnabledStream => _player.shuffleModeEnabledStream;
  Stream<AudioServiceRepeatMode> get repeatModeStream => 
      _player.loopModeStream.map(_convertLoopModeToRepeatMode);
  Stream<String?> get currentMediaId => _player.currentIndexStream
      .asyncMap((index) => _getMediaIdForIndex(index));
  Stream<MediaItem?> get currentMediaItem => _player.currentIndexStream
      .asyncMap((index) => _getMediaItemForIndex(index));

  MyAudioHandler() {
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToCurrentIndex();
  }

  // Helper methods to get media info
  Future<String?> _getMediaIdForIndex(int? index) async {
    if (index == null || _player.audioSource is! ConcatenatingAudioSource) return null;
    final source = (_player.audioSource! as ConcatenatingAudioSource).children[index];
    return (source is UriAudioSource && source.tag is MediaItem) 
        ? (source.tag as MediaItem).id 
        : null;
  }

  Future<MediaItem?> _getMediaItemForIndex(int? index) async {
    if (index == null || _player.audioSource is! ConcatenatingAudioSource) return null;
    final source = (_player.audioSource! as ConcatenatingAudioSource).children[index];
    return (source is UriAudioSource && source.tag is MediaItem) 
        ? source.tag as MediaItem 
        : null;
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((event) {
      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            _player.playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.pause,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: _player.playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: _player.currentIndex,
          shuffleMode: _player.shuffleModeEnabled
              ? AudioServiceShuffleMode.all
              : AudioServiceShuffleMode.none,
          repeatMode: _convertLoopModeToRepeatMode(_player.loopMode),
        ),
      );
    });
  }

  AudioServiceRepeatMode _convertLoopModeToRepeatMode(LoopMode loopMode) {
    switch (loopMode) {
      case LoopMode.off:
        return AudioServiceRepeatMode.none;
      case LoopMode.all:
        return AudioServiceRepeatMode.all;
      case LoopMode.one:
        return AudioServiceRepeatMode.one;
    }
  }

  LoopMode _convertRepeatModeToLoopMode(AudioServiceRepeatMode repeatMode) {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        return LoopMode.off;
      case AudioServiceRepeatMode.all:
        return LoopMode.all;
      case AudioServiceRepeatMode.one:
        return LoopMode.one;
      case AudioServiceRepeatMode.group:
        return LoopMode.all;
    }
  }

  void _listenToCurrentIndex() {
    _player.currentIndexStream.listen((index) {
      if (index != null && _player.audioSource is ConcatenatingAudioSource) {
        final source = (_player.audioSource! as ConcatenatingAudioSource).children[index];
        if (source is UriAudioSource && source.tag is MediaItem) {
          mediaItem.add(source.tag as MediaItem);
        }
      }
    });
  }

  // Playback controls
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> fastForward() async {
    final currentPosition = _player.position;
    final duration = _player.duration ?? Duration.zero;
    final newPosition = currentPosition + const Duration(seconds: 15);
    await seek(newPosition > duration ? duration : newPosition);
  }

  @override
  Future<void> rewind() async {
    final currentPosition = _player.position;
    final newPosition = currentPosition - const Duration(seconds: 15);
    await seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(
      shuffleMode: shuffleMode,
    ));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _player.setLoopMode(_convertRepeatModeToLoopMode(repeatMode));
    playbackState.add(playbackState.value.copyWith(
      repeatMode: repeatMode,
    ));
  }

  // In MyAudioHandler class
  Future<void> setAudioSources(List<AudioSource> sources, {int? initialIndex}) async {
    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: initialIndex,
    );
  }

  Future<void> seekToIndex(int index, [Duration? position]) =>
      _player.seek(position ?? Duration.zero, index: index);

  Future<void> setAudioSource(AudioSource source) =>
      _player.setAudioSource(source);

  // Synchronous access to current media info
  String? get currentMediaIdSync {
    final index = _player.currentIndex;
    if (index == null || _player.audioSource is! ConcatenatingAudioSource) return null;
    final source = (_player.audioSource! as ConcatenatingAudioSource).children[index];
    return (source is UriAudioSource && source.tag is MediaItem) 
        ? (source.tag as MediaItem).id 
        : null;
  }

  MediaItem? get currentMediaItemSync {
    final index = _player.currentIndex;
    if (index == null || _player.audioSource is! ConcatenatingAudioSource) return null;
    final source = (_player.audioSource! as ConcatenatingAudioSource).children[index];
    return (source is UriAudioSource && source.tag is MediaItem) 
        ? source.tag as MediaItem 
        : null;
  }

  // Player state getters
  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  
  Future<void> dispose() async => _player.dispose();
}