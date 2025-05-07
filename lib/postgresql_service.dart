import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class PostgreSQLService {
  static const String _baseUrl = 'https://trip-advisor-woil.onrender.com';

  static Future<void> savePlace(
    String userId,
    Map<String, dynamic> placeData,
  ) async {
    try {
      // Validate input data
      if (userId.isEmpty) {
        throw Exception('User ID is empty');
      }
      if (!placeData.containsKey('id') || placeData['id'] == null) {
        throw Exception('Place ID is missing or null');
      }
      if (!placeData.containsKey('name') || placeData['name'] == null) {
        throw Exception('Place name is missing or null');
      }
      if (!placeData.containsKey('type') || placeData['type'] == null) {
        throw Exception('Place type is missing or null');
      }
      if (!placeData.containsKey('destination') ||
          placeData['destination'] == null) {
        throw Exception('Destination is missing or null');
      }
      if (!placeData.containsKey('lat') || placeData['lat'] == null) {
        throw Exception('Latitude is missing or null');
      }
      if (!placeData.containsKey('lng') || placeData['lng'] == null) {
        throw Exception('Longitude is missing or null');
      }

      // Prepare the request body
      final body = jsonEncode({
        'userId': userId,
        'placeId': placeData['id'].toString(),
        'name': placeData['name'].toString(),
        'type': placeData['type'].toString(),
        'destination': placeData['destination'].toString(),
        'imageUrl': placeData['imageUrl']?.toString(),
        'rating': placeData['rating']?.toDouble() ?? 0.0,
        'reviewCount': placeData['reviewCount']?.toInt() ?? 0,
        'lat': placeData['lat']?.toDouble(),
        'lng': placeData['lng']?.toDouble(),
      });

      // Add Firebase authentication token if required
      String? token;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        token = await user.getIdToken();
      }

      // Send the request
      final response = await http.post(
        Uri.parse('$_baseUrl/api/saved_places'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: body,
      );

      // Handle the response
      if (response.statusCode == 201) {
        print('Place saved successfully: ${response.body}');
        return;
      } else if (response.statusCode == 409) {
        throw Exception('Place already saved for this user');
      } else {
        throw Exception(
          'Failed to save place: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      print('Error saving place: $e\nStackTrace: $stackTrace');
      throw Exception('Failed to save place: $e');
    }
  }

  static Future<void> removePlace(String userId, String placeId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/saved_places/$userId/$placeId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to remove place: ${response.body}');
      }
    } catch (e) {
      print('Error removing place: $e');
      throw Exception('Failed to remove place');
    }
  }

  static Future<List<Map<String, dynamic>>> getSavedPlaces(
    String userId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/saved_places/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to fetch saved places: ${response.body}');
      }
    } catch (e) {
      print('Error getting saved places: $e');
      throw Exception('Failed to get saved places');
    }
  }

  static Future<bool> isPlaceSaved(String userId, String placeId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/saved_places/$userId/$placeId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isSaved'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking if place is saved: $e');
      return false;
    }
  }

  static Future<void> saveTrip(
    String userId,
    Map<String, dynamic> tripData,
  ) async {
    try {
      final itinerary =
          tripData['itinerary'] is List
              ? tripData['itinerary']
              : tripData['itinerary'] is Map &&
                  tripData['itinerary']['items'] != null
              ? tripData['itinerary']['items']
              : [];
      final response = await http.post(
        Uri.parse('$_baseUrl/api/trips'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'name': tripData['name'],
          'itinerary': itinerary,
          'pictureType': tripData['pictureType'],
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to save trip: ${response.body}');
      }
    } catch (e) {
      print('Error saving trip: $e');
      throw Exception('Failed to save trip');
    }
  }

  static Future<List<Map<String, dynamic>>> getUserTrips(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/trips/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        List<Map<String, dynamic>> trips;

        // Handle both raw list and wrapped response
        if (decodedResponse is List) {
          trips = List<Map<String, dynamic>>.from(decodedResponse);
        } else if (decodedResponse is Map) {
          trips = List<Map<String, dynamic>>.from(
            decodedResponse['trips'] ?? decodedResponse['data'] ?? [],
          );
        } else {
          throw Exception('Unexpected response format: $decodedResponse');
        }

        // Normalize itinerary to ensure it's always a List
        for (var trip in trips) {
          if (trip['itinerary'] is Map && trip['itinerary']['items'] != null) {
            trip['itinerary'] = trip['itinerary']['items'];
          }
        }

        return trips;
      } else {
        throw Exception('Failed to fetch trips: ${response.body}');
      }
    } catch (e) {
      print('Error getting trips: $e');
      throw Exception('Failed to get trips');
    }
  }

  static Future<void> updateTrip(
    String tripId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/trips/$tripId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': updates['name'],
          'itinerary': updates['itinerary'],
          'pictureType': updates['pictureType'],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update trip: ${response.body}');
      }
    } catch (e) {
      print('Error updating trip: $e');
      throw Exception('Failed to update trip');
    }
  }

  static Future<void> deleteTrip(String tripId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/trips/$tripId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete trip: ${response.body}');
      }
    } catch (e) {
      print('Error deleting trip: $e');
      throw Exception('Failed to delete trip');
    }
  }
}
