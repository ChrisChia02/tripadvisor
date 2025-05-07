import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trip.dart';

class AIService {
  // Mistral API endpoint (check current URL in their docs)
  static const String _apiUrl = 'https://api.mistral.ai/v1/chat/completions';
  // Get your API key from Mistral platform
  static const String _apiKey = 'TaRv2tRsWO0F57t5Pb6ONCtLMXnU3mSN';

  // Google Places API key - REPLACE WITH YOUR OWN KEY
  static const String _googleApiKey = 'AIzaSyDmnBCSQ3jVr9L54w_iaDlzxHGdcb5lx8A';

  // Default fallback image if Google Places API fails
  static const String _defaultImage =
      'https://static.thenounproject.com/png/5191452-200.png';

  static Future<Trip> generateTrip({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> interests,
    required double budget,
    int travelers = 1,
  }) async {
    final duration = endDate.difference(startDate).inDays;

    final prompt = '''
    Create a detailed $duration-day trip itinerary for $destination from ${startDate.toString()} to ${endDate.toString()}.
    Travelers: $travelers, Budget: \$$budget.
    Interests: ${interests.join(', ')}.
    
    Respond with JSON format exactly as follows:
    {
      "destination": "$destination",
      "startDate": "${startDate.toIso8601String()}",
      "endDate": "${endDate.toIso8601String()}",
      "estimatedCost": 0,
      "itinerary": [
        {
          "dayNumber": 1,
          "morning": [
            {
              "title": "",
              "description": "",
              "location": "",
              "type": "",
              "costEstimated": 0,
              "duration": 0,
              "imageUrl": ""
            }
          ],
          "afternoon": [],
          "evening": []
        }
      ]
    }
    
    Be specific with the "location" field - include full place names, and city/area for best results. This is important for finding images.
    For the "type" field, use one of these categories: restaurant, cafe, attraction, museum, park, beach, shopping, hotel, nightlife, historical, tour, landmark, or activity.
    Leave the "imageUrl" field empty - our app will handle images automatically.
    
    Note: All numerical values must be integers, not decimals. Round any costs to the nearest whole number.
    ''';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': 'mistral-tiny', // or 'mistral-small', 'mistral-medium'
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        // Parse JSON with proper error handling
        try {
          Map<String, dynamic> tripJson = jsonDecode(content);

          // Convert doubles to ints
          _convertDoublesToInts(tripJson);

          // Add images from Google Places API
          await _addImagesFromGooglePlaces(tripJson, destination);

          return Trip.fromJson(tripJson);
        } catch (e) {
          print('JSON parsing error: $e');
          print('Received content: $content');

          // Try to fix the JSON if it has other issues
          try {
            final Map<String, dynamic> jsonMap = jsonDecode(content);
            _convertDoublesToInts(jsonMap);
            await _addImagesFromGooglePlaces(jsonMap, destination);
            return Trip.fromJson(jsonMap);
          } catch (fixError) {
            throw Exception('Failed to parse trip data: $fixError');
          }
        }
      } else {
        throw Exception(
          'Failed to generate trip: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Mistral AI Service error: $e');
    }
  }

  // Recursively convert any double values to int in a JSON object
  static void _convertDoublesToInts(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.forEach((key, value) {
        if (value is double) {
          json[key] = value.round();
        } else if (value is Map || value is List) {
          _convertDoublesToInts(value);
        }
      });
    } else if (json is List) {
      for (int i = 0; i < json.length; i++) {
        if (json[i] is double) {
          json[i] = json[i].round();
        } else if (json[i] is Map || json[i] is List) {
          _convertDoublesToInts(json[i]);
        }
      }
    }
  }

  // Add images from Google Places API based on location and activity type
  static Future<void> _addImagesFromGooglePlaces(
    Map<String, dynamic> tripJson,
    String destination,
  ) async {
    if (tripJson.containsKey('itinerary') && tripJson['itinerary'] is List) {
      for (var dayData in tripJson['itinerary']) {
        if (dayData is Map<String, dynamic>) {
          await _processActivitiesWithGooglePlaces(
            dayData,
            'morning',
            destination,
          );
          await _processActivitiesWithGooglePlaces(
            dayData,
            'afternoon',
            destination,
          );
          await _processActivitiesWithGooglePlaces(
            dayData,
            'evening',
            destination,
          );
        }
      }
    }
  }

  // Process activities for a specific time of day with Google Places
  static Future<void> _processActivitiesWithGooglePlaces(
    Map<String, dynamic> dayData,
    String timeOfDay,
    String destination,
  ) async {
    if (dayData.containsKey(timeOfDay) && dayData[timeOfDay] is List) {
      for (var activity in dayData[timeOfDay]) {
        if (activity is Map<String, dynamic>) {
          final activityType = activity['type']?.toString().toLowerCase() ?? '';
          final location = activity['location']?.toString() ?? '';

          // First try: use the specific location name
          String? imageUrl = await _getPlacePhotoUrl(location, activityType);

          // Second try: use the location + destination
          if (imageUrl == null && location.isNotEmpty) {
            imageUrl = await _getPlacePhotoUrl(
              '$location, $destination',
              activityType,
            );
          }

          // Third try: use the activity title + destination
          if (imageUrl == null && activity['title'] != null) {
            final title = activity['title'].toString();
            imageUrl = await _getPlacePhotoUrl(
              '$title, $destination',
              activityType,
            );
          }

          // Fourth try: use activity type in destination
          if (imageUrl == null && activityType.isNotEmpty) {
            imageUrl = await _getPlacePhotoUrl(
              '$activityType in $destination',
              activityType,
            );
          }

          // Use simple fallback if all attempts failed
          activity['imageUrl'] = imageUrl ?? _defaultImage;
        }
      }
    }
  }

  // Get a photo URL from Google Places API
  static Future<String?> _getPlacePhotoUrl(String query, String type) async {
    if (query.isEmpty || _googleApiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      return null;
    }

    try {
      // Step 1: Find a place ID
      final findPlaceUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?'
        'input=${Uri.encodeComponent(query)}'
        '&inputtype=textquery'
        '&fields=photos,place_id'
        '&key=$_googleApiKey',
      );

      final response = await http.get(findPlaceUrl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK' &&
            data['candidates'] != null &&
            data['candidates'].isNotEmpty) {
          final place = data['candidates'][0];

          // Check if the place has photos
          if (place['photos'] != null && place['photos'].isNotEmpty) {
            final photoReference = place['photos'][0]['photo_reference'];

            // Step 2: Get the photo
            return 'https://maps.googleapis.com/maps/api/place/photo?'
                'maxwidth=400'
                '&photo_reference=$photoReference'
                '&key=$_googleApiKey';
          }
        }
      }

      // If no specific place was found, try a places search instead
      final nearbySearchUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json?'
        'query=${Uri.encodeComponent(query)}'
        '&key=$_googleApiKey',
      );

      final nearbyResponse = await http.get(nearbySearchUrl);

      if (nearbyResponse.statusCode == 200) {
        final data = jsonDecode(nearbyResponse.body);

        if (data['status'] == 'OK' &&
            data['results'] != null &&
            data['results'].isNotEmpty) {
          final place = data['results'][0];

          // Check if the place has photos
          if (place['photos'] != null && place['photos'].isNotEmpty) {
            final photoReference = place['photos'][0]['photo_reference'];

            return 'https://maps.googleapis.com/maps/api/place/photo?'
                'maxwidth=400'
                '&photo_reference=$photoReference'
                '&key=$_googleApiKey';
          }
        }
      }
    } catch (e) {
      print('Google Places API error for query "$query": $e');
    }

    return null;
  }
}
