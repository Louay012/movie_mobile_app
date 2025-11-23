class MovieModel {
  final String id;
  final String title;
  final String posterPath;
  final String? description;
  final double? rating;

  MovieModel({
    required this.id,
    required this.title,
    required this.posterPath,
    this.description,
    this.rating,
  });

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    return MovieModel(
      id: json['id'].toString(),
      title: json['title'] ?? json['name'] ?? 'Unknown',
      posterPath: json['poster_path'] ?? '',
      description: json['overview'],
      rating: (json['vote_average'] as num?)?.toDouble(),
    );
  }
}
