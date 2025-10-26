import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class MusicListScreen extends StatefulWidget {
  final ApiService apiService;

  const MusicListScreen({Key? key, required this.apiService}) : super(key: key);

  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Song> _songs = [];
  bool _isLoading = false;
  bool _isUploading = false;
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        setState(() => _duration = duration);
      }
    });

    _audioPlayer.positionStream.listen((position) {
      setState(() => _position = position);
    });

    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _position = Duration.zero;
        }
      });
    });
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);

    try {
      final songs = await widget.apiService.getSongs();
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading songs: $e')),
        );
      }
    }
  }

  Future<void> _playSong(Song song) async {
    try {
      if (_currentSong == song && _isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      if (_currentSong != song) {
        setState(() => _currentSong = song);
        final url = widget.apiService.getStreamUrl(song.filename);
        await _audioPlayer.setUrl(
          url,
          headers: widget.apiService.streamHeaders,
        );
      }

      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing song: $e')),
        );
      }
    }
  }

  Future<void> _stopSong() async {
    await _audioPlayer.stop();
    setState(() {
      _currentSong = null;
      _position = Duration.zero;
    });
  }

  Future<void> _uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isUploading = true);

        final file = File(result.files.single.path!);
        final success = await widget.apiService.uploadSong(file);

        setState(() => _isUploading = false);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upload successful')),
            );
            _loadSongs();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upload failed')),
            );
          }
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _downloadSong(Song song) async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Storage permission required')),
              );
            }
            return;
          }
        }
      }

      // Get download directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not get storage directory');
      }

      // Create Music subdirectory
      final musicDir = Directory('${directory.path}/Music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final savePath = '${musicDir.path}/${song.filename}';

      // Check if file already exists
      if (await File(savePath).exists()) {
        if (mounted) {
          final shouldOverwrite = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('File exists'),
              content: Text('${song.filename} already exists. Overwrite?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Overwrite'),
                ),
              ],
            ),
          );

          if (shouldOverwrite != true) return;
        }
      }

      setState(() {
        _downloadProgress[song.filename] = 0.0;
      });

      await widget.apiService.downloadSong(
        song.filename,
        savePath,
        onProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _downloadProgress[song.filename] = received / total;
            });
          }
        },
      );

      setState(() {
        _downloadProgress.remove(song.filename);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded to: $savePath')),
        );
      }
    } catch (e) {
      setState(() {
        _downloadProgress.remove(song.filename);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _stopSong();
    await widget.apiService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginScreen(apiService: widget.apiService),
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Music'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _songs.isEmpty
                    ? const Center(
                        child: Text('No songs yet. Upload some music!'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSongs,
                        child: ListView.builder(
                          itemCount: _songs.length,
                          itemBuilder: (context, index) {
                            final song = _songs[index];
                            final isCurrentSong = _currentSong == song;

                            final isDownloading = _downloadProgress.containsKey(song.filename);
                            final progress = _downloadProgress[song.filename] ?? 0.0;

                            return ListTile(
                              leading: Icon(
                                isCurrentSong && _isPlaying
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                color: isCurrentSong ? Colors.blue : null,
                                size: 40,
                              ),
                              title: Text(
                                song.title,
                                style: TextStyle(
                                  fontWeight: isCurrentSong
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(song.sizeInMB),
                              trailing: isDownloading
                                  ? SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            value: progress,
                                            strokeWidth: 2,
                                          ),
                                          Text(
                                            '${(progress * 100).toInt()}%',
                                            style: const TextStyle(fontSize: 8),
                                          ),
                                        ],
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.download),
                                      onPressed: () => _downloadSong(song),
                                    ),
                              onTap: () => _playSong(song),
                            );
                          },
                        ),
                      ),
          ),
          if (_currentSong != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentSong!.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(_formatDuration(_position)),
                      Expanded(
                        child: Slider(
                          value: _position.inSeconds.toDouble(),
                          max: _duration.inSeconds.toDouble(),
                          onChanged: (value) {
                            _audioPlayer.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      Text(_formatDuration(_duration)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.stop),
                        iconSize: 36,
                        onPressed: _stopSong,
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        iconSize: 48,
                        onPressed: () => _playSong(_currentSong!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _uploadFile,
        child: _isUploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_file),
      ),
    );
  }
}
