/// Evidence Model
/// Represents an evidence record in the app
/// Location: lib/models/evidence.dart
library;

class Evidence {
  final int? id;            // local SQLite PK
  final int? serverId;      // backend PK — set after POST /api/evidence/create succeeds
  final int? userId;
  final String evidenceType; // 'video' or 'audio'
  final String localPath;
  final String? fileUrl;     // Google Drive file ID
  final String uploadStatus; // 'pending', 'uploaded', 'failed'
  final int? fileSize;       // bytes
  final int? duration;       // seconds
  final DateTime createdAt;
  final DateTime? uploadedAt;

  Evidence({
    this.id,
    this.serverId,
    this.userId,
    required this.evidenceType,
    required this.localPath,
    this.fileUrl,
    this.uploadStatus = 'pending',
    this.fileSize,
    this.duration,
    required this.createdAt,
    this.uploadedAt,
  });

  /// Create Evidence from JSON (API response)
  factory Evidence.fromJson(Map<String, dynamic> json) {
    return Evidence(
      id: json['id'],
      serverId: json['server_id'],
      userId: json['user_id'],
      evidenceType: json['evidence_type'],
      localPath: json['local_path'],
      fileUrl: json['file_url'],
      uploadStatus: json['upload_status'] ?? 'pending',
      fileSize: json['file_size'],
      duration: json['duration'],
      createdAt: DateTime.parse(json['created_at']),
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'])
          : null,
    );
  }

  /// Convert Evidence to JSON (API request)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'user_id': userId,
      'evidence_type': evidenceType,
      'local_path': localPath,
      'file_url': fileUrl,
      'upload_status': uploadStatus,
      'file_size': fileSize,
      'duration': duration,
      'created_at': createdAt.toIso8601String(),
      'uploaded_at': uploadedAt?.toIso8601String(),
    };
  }

  /// Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'user_id': userId,
      'evidence_type': evidenceType,
      'local_path': localPath,
      'file_url': fileUrl,
      'upload_status': uploadStatus,
      'file_size': fileSize,
      'duration': duration,
      'created_at': createdAt.toIso8601String(),
      'uploaded_at': uploadedAt?.toIso8601String(),
    };
  }

  /// Create Evidence from SQLite Map
  factory Evidence.fromMap(Map<String, dynamic> map) {
    return Evidence(
      id: map['id'],
      serverId: map['server_id'],
      userId: map['user_id'],
      evidenceType: map['evidence_type'],
      localPath: map['local_path'],
      fileUrl: map['file_url'],
      uploadStatus: map['upload_status'] ?? 'pending',
      fileSize: map['file_size'],
      duration: map['duration'],
      createdAt: DateTime.parse(map['created_at']),
      uploadedAt: map['uploaded_at'] != null
          ? DateTime.parse(map['uploaded_at'])
          : null,
    );
  }

  /// Copy with modifications
  Evidence copyWith({
    int? id,
    int? serverId,
    int? userId,
    String? evidenceType,
    String? localPath,
    String? fileUrl,
    String? uploadStatus,
    int? fileSize,
    int? duration,
    DateTime? createdAt,
    DateTime? uploadedAt,
  }) {
    return Evidence(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      evidenceType: evidenceType ?? this.evidenceType,
      localPath: localPath ?? this.localPath,
      fileUrl: fileUrl ?? this.fileUrl,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  @override
  String toString() {
    return 'Evidence(id: $id, serverId: $serverId, type: $evidenceType, status: $uploadStatus)';
  }
}