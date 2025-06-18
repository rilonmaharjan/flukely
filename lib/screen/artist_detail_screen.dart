import 'package:audio_service/audio_service.dart';
import 'package:flukely/services/my_audio_handler.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class ArtistDetailPage extends StatelessWidget {
  final ArtistModel artist;
  final AudioHandler audioHandler;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  
   ArtistDetailPage({
    super.key,
    required this.artist,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(artist.artist),
        backgroundColor: Colors.deepPurpleAccent.withValues(alpha:.1),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<SongModel>>(
        future: _audioQuery.queryAudiosFrom(
          AudiosFromType.ARTIST_ID,
          artist.id,
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
                  Icon(Icons.music_off, size: 50, color: Colors.white70),
                  SizedBox(height: 20),
                  Text('No Songs Found', 
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            );
          }
          
          final songs = snapshot.data!;
          final audioHandler = this.audioHandler as MyAudioHandler;
          
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.deepPurpleAccent.withValues(alpha:.1),
                Colors.purpleAccent.withValues(alpha:.1),
              ])
            ),
            child: ListView.separated(
              padding: EdgeInsets.only(bottom: 80),
              itemCount: songs.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey[800],
                height: 1,
                indent: 80,
              ),
              itemBuilder: (context, index) {
                final song = songs[index];
                return InkWell(
                  onTap: () async {
                    await audioHandler.skipToQueueItem(index);
                    await audioHandler.play();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            artworkBorder: BorderRadius.circular(8),
                            nullArtworkWidget: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.deepPurpleAccent.withValues(alpha:.35),
                                  Colors.purpleAccent.withValues(alpha:.35),
                                ])
                              ),
                              child: Icon(Icons.music_note, color: Colors.white70),
                            ),
                            artworkWidth: 60,
                            artworkHeight: 60,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                song.album ?? 'Unknown Album',
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
                                : Icon(
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
        },
      ),
    );
  }
}