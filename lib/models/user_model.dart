class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String bio;
  final String profilePicUrl;
  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.bio,
    required this.profilePicUrl,
  });
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      bio: map['bio'] ?? '',
      profilePicUrl: map['profilePicUrl'] ?? '',
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'bio': bio,
      'profilePicUrl': profilePicUrl,
    };
  }
  
}
