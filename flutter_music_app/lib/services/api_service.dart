import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

class ApiService {
  static const String _tokenKey = 'auth_token';
  static const String _serverUrlKey = 'server_url';

  String? _token;
  String _baseUrl = 'http://192.168.1.100:5000'; // Default, can be changed

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _baseUrl = prefs.getString(_serverUrlKey) ?? _baseUrl;
  }

  Future<void> setServerUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }

  String get baseUrl => _baseUrl;

  Future<bool> login(String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': apiKey}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];

        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _token!);

        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
      };

  Future<List<Song>> getSongs() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/songs'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List songsList = data['songs'];
        return songsList.map((json) => Song.fromJson(json)).toList();
      }
      throw Exception('Failed to load songs');
    } catch (e) {
      print('Get songs error: $e');
      rethrow;
    }
  }

  String getStreamUrl(String filename) {
    return '$_baseUrl/stream/$filename';
  }

  Map<String, String> get streamHeaders => _headers;

  Future<bool> uploadSong(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/upload'),
      );

      request.headers.addAll(_headers);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 201;
    } catch (e) {
      print('Upload error: $e');
      return false;
    }
  }

  Future<void> downloadSong(
    String filename,
    String savePath, {
    Function(int, int)? onProgress,
  }) async {
    try {
      final dio = Dio();
      await dio.download(
        '$_baseUrl/download/$filename',
        savePath,
        options: Options(
          headers: _headers,
        ),
        onReceiveProgress: onProgress,
      );
    } catch (e) {
      print('Download error: $e');
      rethrow;
    }
  }
}
