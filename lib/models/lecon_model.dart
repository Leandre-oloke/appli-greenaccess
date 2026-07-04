class LeconModel {
  final String id;
  final String titre;
  final String contenu;
  final String? urlVideo;
  final String? urlPdf;
  final int ordre;

  const LeconModel({
    required this.id,
    required this.titre,
    required this.contenu,
    this.urlVideo,
    this.urlPdf,
    required this.ordre,
  });

  factory LeconModel.fromFirestore(Map<String, dynamic> data, String id) {
    return LeconModel(
      id: id,
      titre: data['titre'] ?? '',
      contenu: data['contenu'] ?? '',
      urlVideo: data['url_video'],
      urlPdf: data['url_pdf'],
      ordre: data['ordre'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'titre': titre,
    'contenu': contenu,
    'url_video': urlVideo,
    'url_pdf': urlPdf,
    'ordre': ordre,
  };
}
