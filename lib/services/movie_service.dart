import 'dart:convert';
import 'package:http/http.dart' as http;

class MovieService {
  final String apiKey = "90eac833e9ddd5d6ddcf1ed1ca6044fc";

  Future<List<dynamic>> getPopularMovies() async {
    final uri = Uri.parse(
      "https://api.themoviedb.org/3/movie/popular?api_key=$apiKey",
    );

    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["results"];
    } else {
      throw Exception("Failed to load movies");
    }
  }
}
