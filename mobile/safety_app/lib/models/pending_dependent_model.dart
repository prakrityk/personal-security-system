// lib/models/pending_dependent_model.dart

/// Model for creating a pending dependent
class PendingDependentCreate {
  final String dependentName;
  final String relation;
  final int age;

  PendingDependentCreate({
    required this.dependentName,
    required this.relation,
    required this.age,
  });

  Map<String, dynamic> toJson() {
    return {'dependent_name': dependentName, 'relation': relation, 'age': age};
  }
}

/// Model for pending dependent response
class PendingDependentResponse {
  final int id;
  final int guardianId;
  final String dependentName;
  final String relation;
  final int age;
  final DateTime createdAt;

  PendingDependentResponse({
    required this.id,
    required this.guardianId,
    required this.dependentName,
    required this.relation,
    required this.age,
    required this.createdAt,
  });

  factory PendingDependentResponse.fromJson(Map<String, dynamic> json) {
    return PendingDependentResponse(
      id: json['id'],
      guardianId: json['guardian_id'],
      dependentName: json['dependent_name'],
      relation: json['relation'],
      age: json['Age'] ?? json['age'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guardian_id': guardianId,
      'dependent_name': dependentName,
      'relation': relation,
      'Age': age,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Model for pending dependent with QR info
class PendingDependentWithQR {
  final int id;
  final int guardianId;
  final String dependentName;
  final String relation;
  final int age;
  final DateTime createdAt;
  final bool hasQr;
  final String? qrStatus;
  final String? qrToken;

  PendingDependentWithQR({
    required this.id,
    required this.guardianId,
    required this.dependentName,
    required this.relation,
    required this.age,
    required this.createdAt,
    this.hasQr = false,
    this.qrStatus,
    this.qrToken,
  });

  factory PendingDependentWithQR.fromJson(Map<String, dynamic> json) {
    return PendingDependentWithQR(
      id: json['id'],
      guardianId: json['guardian_id'],
      dependentName: json['dependent_name'],
      relation: json['relation'],
      age: json['Age'] ?? json['age'],
      createdAt: DateTime.parse(json['created_at']),
      hasQr: json['has_qr'] ?? false,
      qrStatus: json['qr_status'],
      qrToken: json['qr_token'],
    );
  }
}

/// Model for QR generation request
class GenerateQRRequest {
  final int pendingDependentId;

  GenerateQRRequest({required this.pendingDependentId});

  Map<String, dynamic> toJson() {
    return {'pending_dependent_id': pendingDependentId};
  }
}

/// ✅ FIXED: Model for QR generation response - matches actual backend response
class GenerateQRResponse {
  final bool success;
  final String message;
  final String qrToken;
  final DateTime expiresAt;
  final int pendingDependentId;

  GenerateQRResponse({
    required this.success,
    required this.message,
    required this.qrToken,
    required this.expiresAt,
    required this.pendingDependentId,
  });

  factory GenerateQRResponse.fromJson(Map<String, dynamic> json) {
    return GenerateQRResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      qrToken: json['qr_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      pendingDependentId: json['pending_dependent_id'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'qr_token': qrToken,
      'expires_at': expiresAt.toIso8601String(),
      'pending_dependent_id': pendingDependentId,
    };
  }
}
