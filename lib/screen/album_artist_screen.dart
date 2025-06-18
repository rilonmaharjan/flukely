import 'package:audio_service/audio_service.dart';
import 'package:flukely/screen/album_detail_screen.dart';
import 'package:flukely/screen/artist_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class AlbumArtistsPage extends StatelessWidget {
  final AudioHandler audioHandler;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  
  AlbumArtistsPage({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.deepPurpleAccent.withValues(alpha: .1),
          Colors.purpleAccent.withValues(alpha: .1),
        ])
      ),
      child: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          _audioQuery.queryArtists(),
          _audioQuery.queryAlbums(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center();
          }
          
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.white70),
                  const SizedBox(height: 20),
                  const Text('Failed to load content', 
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                  TextButton(
                    onPressed: () {
                      // Optionally add refresh logic here
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }
          
          final artists = snapshot.data![0] as List<ArtistModel>;
          final albums = snapshot.data![1] as List<AlbumModel>;
          
          return CustomScrollView(
            slivers: [
              // Artists section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Artists',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              if (artists.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.person_off, size: 50, color: Colors.white70),
                        const SizedBox(height: 10),
                        const Text('No Artists Found', 
                          style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final artist = artists[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: QueryArtworkWidget(
                            id: artist.id,
                            type: ArtworkType.ARTIST,
                            artworkWidth: 50,
                            artworkHeight: 50,
                            nullArtworkWidget: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.deepPurpleAccent.withValues(alpha:0.35),
                                  Colors.purpleAccent.withValues(alpha:0.35),
                                ])
                              ),
                              child: const Icon(Icons.person, color: Colors.white70),
                            ),
                          ),
                        ),
                        title: Text(
                          artist.artist,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${artist.numberOfAlbums} albums • ${artist.numberOfTracks} songs',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ArtistDetailPage(
                                artist: artist,
                                audioHandler: audioHandler,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: artists.length,
                  ),
                ),
              
              // Albums section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Albums',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              if (albums.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.album_outlined, size: 50, color: Colors.white70),
                        const SizedBox(height: 10),
                        const Text('No Albums Found', 
                          style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom :88.0),
                    child: SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: albums.length,
                        itemBuilder: (context, index) {
                          final album = albums[index];
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AlbumDetailPage(
                                    album: album,
                                    audioHandler: audioHandler,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 150,
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: QueryArtworkWidget(
                                      id: album.id,
                                      type: ArtworkType.ALBUM,
                                      artworkWidth: 150,
                                      artworkHeight: 150,
                                      artworkBorder: BorderRadius.circular(8),
                                      nullArtworkWidget: Container(
                                        width: 150,
                                        height: 150,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            Colors.deepPurpleAccent.withValues(alpha:0.35),
                                            Colors.purpleAccent.withValues(alpha:0.35),
                                          ])
                                        ),
                                        child: const Icon(Icons.album, size: 50, color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    album.album,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    album.artist ?? 'Unknown Artist',
                                    style: TextStyle(color: Colors.grey[400]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}