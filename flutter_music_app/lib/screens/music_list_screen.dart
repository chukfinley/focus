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
        _showSnackBar('Error loading songs: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF03DAC6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
        _showSnackBar('Error playing song: $e', isError: true);
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
        allowMultiple: true,  // Enable multiple file selection
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isUploading = true);

        // Get all selected files
        final files = result.files
            .where((file) => file.path != null)
            .map((file) => File(file.path!))
            .toList();

        if (files.isEmpty) {
          setState(() => _isUploading = false);
          if (mounted) {
            _showSnackBar('No valid files selected', isError: true);
          }
          return;
        }

        // Upload multiple files
        final uploadResult = await widget.apiService.uploadMultipleSongs(files);

        setState(() => _isUploading = false);

        if (mounted) {
          final uploaded = uploadResult['uploaded'] ?? 0;
          final failed = uploadResult['failed'] ?? 0;

          if (uploaded > 0) {
            _loadSongs();

            if (failed > 0) {
              _showSnackBar(
                'Uploaded $uploaded file(s), $failed failed',
                isError: true,
              );
            } else {
              _showSnackBar(
                'Successfully uploaded $uploaded file(s)',
              );
            }
          } else {
            _showSnackBar('Upload failed', isError: true);
          }
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
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
              _showSnackBar('Storage permission required', isError: true);
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
      } else {
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
              backgroundColor: const Color(0xFF1D1E33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('File exists'),
              content: Text('${song.filename} already exists. Overwrite?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
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
        _showSnackBar('Downloaded successfully');
      }
    } catch (e) {
      setState(() {
        _downloadProgress.remove(song.filename);
      });

      if (mounted) {
        _showSnackBar('Download error: $e', isError: true);
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
        title: const Text(
          'My Music',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6C63FF),
                    ),
                  )
                : _songs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_off,
                              size: 80,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No songs yet',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload some music to get started!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSongs,
                        color: const Color(0xFF6C63FF),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _songs.length,
                          itemBuilder: (context, index) {
                            final song = _songs[index];
                            final isCurrentSong = _currentSong == song;
                            final isDownloading = _downloadProgress.containsKey(song.filename);
                            final progress = _downloadProgress[song.filename] ?? 0.0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                child: InkWell(
                                  onTap: () => _playSong(song),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: isCurrentSong
                                                ? const Color(0xFF6C63FF)
                                                : const Color(0xFF6C63FF).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            isCurrentSong && _isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                song.title,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: isCurrentSong
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  color: isCurrentSong
                                                      ? const Color(0xFF6C63FF)
                                                      : Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                song.sizeInMB,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white.withOpacity(0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isDownloading)
                                          SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                CircularProgressIndicator(
                                                  value: progress,
                                                  strokeWidth: 3,
                                                  color: const Color(0xFF03DAC6),
                                                  backgroundColor: Colors.white.withOpacity(0.1),
                                                ),
                                                Text(
                                                  '${(progress * 100).toInt()}%',
                                                  style: const TextStyle(fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          IconButton(
                                            icon: const Icon(Icons.download_rounded),
                                            color: const Color(0xFF03DAC6),
                                            onPressed: () => _downloadSong(song),
                                            tooltip: 'Download',
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          if (_currentSong != null) _buildMusicPlayer(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _uploadFile,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_rounded),
        label: Text(_isUploading ? 'Uploading...' : 'Upload'),
      ),
    );
  }

  Widget _buildMusicPlayer() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.8),
            const Color(0xFF03DAC6).withOpacity(0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentSong!.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Now Playing',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: _stopSong,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    _formatDuration(_position),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withOpacity(0.3),
                      ),
                      child: Slider(
                        value: _position.inSeconds.toDouble(),
                        max: _duration.inSeconds.toDouble(),
                        onChanged: (value) {
                          _audioPlayer.seek(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    iconSize: 48,
                    color: Colors.white,
                    onPressed: () => _playSong(_currentSong!),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
