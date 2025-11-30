import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // <-- add this line

class MovieService {
  final String apiKey = "90eac833e9ddd5d6ddcf1ed1ca6044fc";

  Future<List<dynamic>> getPopularMovies(int page) async {
    final uri = Uri.parse(
      "https://api.themoviedb.org/3/movie/popular?api_key=$apiKey&page=$page",
    );

    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      debugPrint('first result: ${jsonEncode(data["results"][0])}');

      return data["results"];
    } else {
      throw Exception("Failed to load movies");
    }
  }
}
