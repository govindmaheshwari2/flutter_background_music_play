import 'package:audio_service/audio_service.dart';
import 'package:background_music/database.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

MediaItem mediaItem = MediaItem(
    id: songList[0].url,
    title: songList[0].name,
    artUri: Uri.parse(songList[0].icon),
    album: songList[0].album,
    duration: songList[0].duration,
    artist: songList[0].artist);

int current = 0;

_backgroundTaskEntrypoint() {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

class AudioPlayerTask extends BackgroundAudioTask {
  final _audioPlayer = AudioPlayer();

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    AudioServiceBackground.setState(controls: [
      MediaControl.pause,
      MediaControl.stop,
      MediaControl.skipToNext,
      MediaControl.skipToPrevious
    ], systemActions: [
      MediaAction.seekTo
    ], playing: true, processingState: AudioProcessingState.connecting);
    // Connect to the URL
    await _audioPlayer.setUrl(mediaItem.id);
    AudioServiceBackground.setMediaItem(mediaItem);
    // Now we're ready to play
    _audioPlayer.play();
    // Broadcast that we're playing, and what controls are available.
    AudioServiceBackground.setState(controls: [
      MediaControl.pause,
      MediaControl.stop,
      MediaControl.skipToNext,
      MediaControl.skipToPrevious
    ], systemActions: [
      MediaAction.seekTo
    ], playing: true, processingState: AudioProcessingState.ready);
  }

  @override
  Future<void> onStop() async {
    AudioServiceBackground.setState(
        controls: [],
        playing: false,
        processingState: AudioProcessingState.ready);
    await _audioPlayer.stop();
    await super.onStop();
  }

  @override
  Future<void> onPlay() async {
    AudioServiceBackground.setState(controls: [
      MediaControl.pause,
      MediaControl.stop,
      MediaControl.skipToNext,
      MediaControl.skipToPrevious
    ], systemActions: [
      MediaAction.seekTo
    ], playing: true, processingState: AudioProcessingState.ready);
    await _audioPlayer.play();
    return super.onPlay();
  }

  @override
  Future<void> onPause() async {
    AudioServiceBackground.setState(controls: [
      MediaControl.play,
      MediaControl.stop,
      MediaControl.skipToNext,
      MediaControl.skipToPrevious
    ], systemActions: [
      MediaAction.seekTo
    ], playing: false, processingState: AudioProcessingState.ready);
    await _audioPlayer.pause();
    return super.onPause();
  }

  @override
  Future<void> onSkipToNext() async {
    if (current < songList.length - 1)
      current = current + 1;
    else
      current = 0;
    mediaItem = MediaItem(
        id: songList[current].url,
        title: songList[current].name,
        artUri: Uri.parse(songList[current].icon),
        album: songList[current].album,
        duration: songList[current].duration,
        artist: songList[current].artist);
    AudioServiceBackground.setMediaItem(mediaItem);
    await _audioPlayer.setUrl(mediaItem.id);
    AudioServiceBackground.setState(position: Duration.zero);
    return super.onSkipToNext();
  }

  @override
  Future<void> onSkipToPrevious() async {
    if (current != 0)
      current = current - 1;
    else
      current = songList.length - 1;
    mediaItem = MediaItem(
        id: songList[current].url,
        title: songList[current].name,
        artUri: Uri.parse(songList[current].icon),
        album: songList[current].album,
        duration: songList[current].duration,
        artist: songList[current].artist);
    AudioServiceBackground.setMediaItem(mediaItem);
    await _audioPlayer.setUrl(mediaItem.id);
    AudioServiceBackground.setState(position: Duration.zero);
    return super.onSkipToPrevious();
  }

  @override
  Future<void> onSeekTo(Duration position) {
    _audioPlayer.seek(position);
    AudioServiceBackground.setState(position: position);
    return super.onSeekTo(position);
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
            appBar: AppBar(
              title: Text("Background Music"),
              actions: [
                IconButton(
                    icon: Icon(Icons.stop),
                    onPressed: () {
                      AudioService.stop();
                    })
              ],
            ),
            body: Center(
              child: Column(
                children: [
                  StreamBuilder<MediaItem>(
                      stream: AudioService.currentMediaItemStream,
                      builder: (_, snapshot) {
                        return Text(snapshot.data?.title ?? "title");
                      }),
                  StreamBuilder<PlaybackState>(
                      stream: AudioService.playbackStateStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        if (playing)
                          return ElevatedButton(
                              child: Text("Pause"),
                              onPressed: () {
                                AudioService.pause();
                              });
                        else
                          return ElevatedButton(
                              child: Text("Play"),
                              onPressed: () {
                                if (AudioService.running) {
                                  AudioService.play();
                                } else {
                                  AudioService.start(
                                    backgroundTaskEntrypoint:
                                        _backgroundTaskEntrypoint,
                                  );
                                }
                              });
                      }),
                  ElevatedButton(
                      onPressed: () async {
                        await AudioService.skipToNext();
                      },
                      child: Text("Next Song")),
                  ElevatedButton(
                      onPressed: () async {
                        await AudioService.skipToPrevious();
                      },
                      child: Text("Previous Song")),
                  StreamBuilder<Duration>(
                    stream: AudioService.positionStream,
                    builder: (_, snapshot) {
                      final mediaState = snapshot.data;
                      return Slider(
                        value: mediaState?.inSeconds?.toDouble() ?? 0,
                        min: 0,
                        max: mediaItem.duration.inSeconds.toDouble(),
                        onChanged: (val) {
                          AudioService.seekTo(Duration(seconds: val.toInt()));
                        },
                      );
                    },
                  )
                ],
              ),
            )));
  }
}
