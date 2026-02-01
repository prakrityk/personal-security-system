class Role {
  final int id;
  final String roleName;
  
  Role({
    required this.id,
    required this.roleName,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as int,
      roleName: json['role_name'] as String,
    );
  }
}