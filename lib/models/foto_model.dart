class FotoModel {
  final int fotoId;
  final String judulFoto;
  final String deskripsiFoto;
  final DateTime tanggalUnggah;
  final String lokasiFile;
  final int albumId;
  final int userId;

  FotoModel({
    required this.fotoId,
    required this.judulFoto,
    required this.deskripsiFoto,
    required this.tanggalUnggah,
    required this.lokasiFile,
    required this.albumId,
    required this.userId,
  });

  factory FotoModel.fromJson(Map<String, dynamic> json) {
    return FotoModel(
      fotoId: json['FotoID'],
      judulFoto: json['JudulFoto'],
      deskripsiFoto: json['DeskripsiFoto'],
      tanggalUnggah: DateTime.parse(json['TanggalUnggah']),
      lokasiFile: json['LokasiFile'],
      albumId: json['AlbumID'],
      userId: json['UserID'],
    );
  }
}