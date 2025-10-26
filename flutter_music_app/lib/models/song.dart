class Song {
  final String filename;
  final int size;
  final String uploadedAt;
  final String title;

  Song({
    required this.filename,
    required this.size,
    required this.uploadedAt,
    required this.title,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      filename: json['filename'] ?? '',
      size: json['size'] ?? 0,
      uploadedAt: json['uploaded_at'] ?? '',
      title: json['title'] ?? json['filename'] ?? '',
    );
  }

  String get sizeInMB => '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
}
