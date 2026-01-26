class RoleInfo {
  final int id;
  final String roleName;
  final String? roleDescription;

  RoleInfo({
    required this.id,
    required this.roleName,
    this.roleDescription,
  });

  factory RoleInfo.fromJson(Map<String, dynamic> json) {
    return RoleInfo(
      id: json['id'],
      roleName: json['role_name'],
      roleDescription: json['role_description'],
    );
  }
    Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role_name': roleName,
      'role_description': roleDescription,
    };
  }
}
