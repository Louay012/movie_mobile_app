import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class MovieServiceException implements Exception {
  final String message;
  final int? statusCode;
  
  MovieServiceException(this.message, {this.statusCode});
  
  @override
  String toString() => message;
}

class MovieService {
  final String apiKey = "90eac833e9ddd5d6ddcf1ed1ca6044fc";
  static const String baseUrl = "https://api.themoviedb.org/3";
  static const int timeoutSeconds = 15;

  Future<List<dynamic>> getPopularMovies(int page) async {
    if (page < 1) {
      throw MovieServiceException('Invalid page number: $page');
    }

    final uri = Uri.parse(
      "$baseUrl/movie/popular?api_key=$apiKey&page=$page",
    );

    try {
      final res = await http
          .get(uri)
          .timeout(
            const Duration(seconds: timeoutSeconds),
            onTimeout: () {
              throw MovieServiceException(
                'Request timed out after $timeoutSeconds seconds',
              );
            },
          );

      // Handle different status codes
      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body);
          
          // Validate response structure
          if (data is! Map<String, dynamic>) {
            throw MovieServiceException('Invalid response format');
          }
          
          if (!data.containsKey('results')) {
            throw MovieServiceException('Missing results in response');
          }
          
          final results = data["results"];
          
          if (results is! List) {
            throw MovieServiceException('Results is not a list');
          }
          
          return results;
        } on FormatException catch (e) {
          throw MovieServiceException(
            'Failed to parse response: ${e.message}',
          );
        }
      } else if (res.statusCode == 401) {
        throw MovieServiceException(
          'Invalid API key or unauthorized access',
          statusCode: 401,
        );
      } else if (res.statusCode == 404) {
        throw MovieServiceException(
          'Resource not found',
          statusCode: 404,
        );
      } else if (res.statusCode >= 500) {
        throw MovieServiceException(
          'Server error (${res.statusCode}). Please try again later.',
          statusCode: res.statusCode,
        );
      } else {
        throw MovieServiceException(
          'Request failed with status: ${res.statusCode}',
          statusCode: res.statusCode,
        );
      }
    } on SocketException {
      throw MovieServiceException(
        'No internet connection. Please check your network.',
      );
    } on TimeoutException {
      throw MovieServiceException(
        'Connection timed out. Please try again.',
      );
    } on MovieServiceException {
      rethrow;
    } catch (e) {
      throw MovieServiceException(
        'Unexpected error: ${e.toString()}',
      );
    }
  }

  // Optional: Add a method to search movies with the same error handling
  Future<List<dynamic>> searchMovies(String query, {int page = 1}) async {
    if (query.isEmpty) {
      throw MovieServiceException('Search query cannot be empty');
    }

    final uri = Uri.parse(
      "$baseUrl/search/movie?api_key=$apiKey&query=${Uri.encodeComponent(query)}&page=$page",
    );

    try {
      final res = await http
          .get(uri)
          .timeout(
            const Duration(seconds: timeoutSeconds),
            onTimeout: () {
              throw MovieServiceException(
                'Request timed out after $timeoutSeconds seconds',
              );
            },
          );

      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body);
          
          if (data is! Map<String, dynamic> || !data.containsKey('results')) {
            throw MovieServiceException('Invalid response format');
          }
          
          return data["results"] as List;
        } on FormatException catch (e) {
          throw MovieServiceException(
            'Failed to parse response: ${e.message}',
          );
        }
      } else {
        throw MovieServiceException(
          'Search failed with status: ${res.statusCode}',
          statusCode: res.statusCode,
        );
      }
    } on SocketException {
      throw MovieServiceException(
        'No internet connection. Please check your network.',
      );
    } on TimeoutException {
      throw MovieServiceException(
        'Connection timed out. Please try again.',
      );
    } on MovieServiceException {
      rethrow;
    } catch (e) {
      throw MovieServiceException(
        'Unexpected error: ${e.toString()}',
      );
    }
  }

  // Optional: Get movie details with error handling
  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final uri = Uri.parse(
      "$baseUrl/movie/$movieId?api_key=$apiKey",
    );

    try {
      final res = await http
          .get(uri)
          .timeout(
            const Duration(seconds: timeoutSeconds),
            onTimeout: () {
              throw MovieServiceException(
                'Request timed out after $timeoutSeconds seconds',
              );
            },
          );

      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body);
          
          if (data is! Map<String, dynamic>) {
            throw MovieServiceException('Invalid response format');
          }
          
          return data;
        } on FormatException catch (e) {
          throw MovieServiceException(
            'Failed to parse response: ${e.message}',
          );
        }
      } else if (res.statusCode == 404) {
        throw MovieServiceException(
          'Movie not found',
          statusCode: 404,
        );
      } else {
        throw MovieServiceException(
          'Request failed with status: ${res.statusCode}',
          statusCode: res.statusCode,
        );
      }
    } on SocketException {
      throw MovieServiceException(
        'No internet connection. Please check your network.',
      );
    } on TimeoutException {
      throw MovieServiceException(
        'Connection timed out. Please try again.',
      );
    } on MovieServiceException {
      rethrow;
    } catch (e) {
      throw MovieServiceException(
        'Unexpected error: ${e.toString()}',
      );
    }
  }

  Future<String?> getMovieTrailer(int movieId) async {
    final uri = Uri.parse(
      "$baseUrl/movie/$movieId/videos?api_key=$apiKey",
    );

    try {
      final res = await http
          .get(uri)
          .timeout(
            const Duration(seconds: timeoutSeconds),
            onTimeout: () {
              throw MovieServiceException(
                'Request timed out after $timeoutSeconds seconds',
              );
            },
          );

      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body);
          
          if (data is! Map<String, dynamic> || !data.containsKey('results')) {
            return null;
          }
          
          final videos = data['results'] as List;
          
          // Find official trailer first, then any trailer, then teaser
          for (final type in ['Trailer', 'Teaser']) {
            for (final video in videos) {
              if (video['site'] == 'YouTube' && 
                  video['type'] == type &&
                  video['official'] == true) {
                return video['key'];
              }
            }
            // Fallback to non-official
            for (final video in videos) {
              if (video['site'] == 'YouTube' && video['type'] == type) {
                return video['key'];
              }
            }
          }
          
          // Last resort: any YouTube video
          for (final video in videos) {
            if (video['site'] == 'YouTube') {
              return video['key'];
            }
          }
          
          return null;
        } on FormatException {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<int, String>> getGenres() async {
    final uri = Uri.parse(
      "$baseUrl/genre/movie/list?api_key=$apiKey",
    );

    try {
      final res = await http
          .get(uri)
          .timeout(
            const Duration(seconds: timeoutSeconds),
          );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final genres = data['genres'] as List;
        return {
          for (var g in genres) g['id'] as int: g['name'] as String
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
