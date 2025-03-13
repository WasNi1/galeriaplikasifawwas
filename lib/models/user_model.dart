class UserModel {
  final int userId;
  final String firebaseUid;
  final String username;
  final String email;
  final String? profilePhoto;
  final String namaLengkap;
  final String alamat;

  UserModel({
    required this.userId,
    required this.firebaseUid,
    required this.username,
    required this.email,
    this.profilePhoto,
    required this.namaLengkap,
    required this.alamat,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['UserID'],
      firebaseUid: json['firebase_uid'],
      username: json['Username'],
      email: json['Email'],
      profilePhoto: json['profile_photo'],
      namaLengkap: json['NamaLengkap'],
      alamat: json['Alamat'],
    );
  }
}