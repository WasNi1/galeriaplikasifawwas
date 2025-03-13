class AlbumModel {
  final int albumId;
  final String namaAlbum;
  final String deskripsi;
  final DateTime tanggalDibuat;
  final int userId;

  AlbumModel({
    required this.albumId,
    required this.namaAlbum,
    required this.deskripsi,
    required this.tanggalDibuat,
    required this.userId,
  });

  factory AlbumModel.fromJson(Map<String, dynamic> json) {
    return AlbumModel(
      albumId: json['AlbumID'],
      namaAlbum: json['NamaAlbum'],
      deskripsi: json['Deskripsi'],
      tanggalDibuat: DateTime.parse(json['TanggalDibuat']),
      userId: json['UserID'],
    );
  }
}