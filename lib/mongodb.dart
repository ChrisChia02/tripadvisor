// mongodb.dart
import 'package:mongo_dart/mongo_dart.dart';
import 'constant.dart';

class MongoDatabase {
  static late Db _db;

  static Future<void> connect() async {
    _db = await Db.create(MONGO_URL);
    //await _db.open();
    print("Connected to MongoDB");
  }

  static Future<void> disconnect() async {
    await _db.close();
  }

  static Future<void> savePlace(
    String userId,
    Map<String, dynamic> placeData,
  ) async {
    try {
      var collection = _db.collection(COLLECTION_NAME);
      placeData['userId'] = userId; // Associate place with user
      await collection.insert(placeData);
    } catch (e) {
      print("Error saving place: $e");
      throw Exception("Failed to save place");
    }
  }

  static Future<void> removePlace(String userId, String placeId) async {
    try {
      var collection = _db.collection(COLLECTION_NAME);
      await collection.deleteOne({'userId': userId, 'id': placeId});
    } catch (e) {
      print("Error removing place: $e");
      throw Exception("Failed to remove place");
    }
  }

  static Future<List<Map<String, dynamic>>> getSavedPlaces(
    String userId,
  ) async {
    try {
      var collection = _db.collection(COLLECTION_NAME);
      return await collection.find({'userId': userId}).toList();
    } catch (e) {
      print("Error getting saved places: $e");
      throw Exception("Failed to get saved places");
    }
  }

  static Future<bool> isPlaceSaved(String userId, String placeId) async {
    try {
      var collection = _db.collection(COLLECTION_NAME);
      var place = await collection.findOne({'userId': userId, 'id': placeId});
      return place != null;
    } catch (e) {
      print("Error checking if place is saved: $e");
      return false;
    }
  }

  static Future<void> saveTrip(
    String userId,
    Map<String, dynamic> tripData,
  ) async {
    try {
      var collection = _db.collection('trips');
      tripData['userId'] = userId;
      tripData['createdAt'] = DateTime.now();
      await collection.insert(tripData);
    } catch (e) {
      print("Error saving trip: $e");
      throw Exception("Failed to save trip");
    }
  }

  // Update the getUserTrips method in mongodb.dart
  static Future<List<Map<String, dynamic>>> getUserTrips(String userId) async {
    try {
      var collection = _db.collection('trips');
      var trips = await collection.find({'userId': userId}).toList();

      // Convert ObjectId to String
      return trips.map((trip) {
        if (trip['_id'] is ObjectId) {
          trip['_id'] = trip['_id'].$oid; // or trip['_id'].toString()
        }
        return trip;
      }).toList();
    } catch (e) {
      print("Error getting trips: $e");
      throw Exception("Failed to get trips");
    }
  }

  static Future<void> updateTrip(
    String tripId,
    Map<String, dynamic> updates,
  ) async {
    try {
      var collection = _db.collection('trips');
      var modifier = modify;

      // Add all fields from updates to the modifier
      updates.forEach((key, value) {
        if (key != '_id') {
          // Skip the ID field
          modifier = modifier.set(key, value);
        }
      });

      // Always update the timestamp
      modifier = modifier.set('updatedAt', DateTime.now());

      await collection.update(
        where.eq('_id', ObjectId.fromHexString(tripId)),
        modifier,
      );
    } catch (e) {
      print("Error updating trip: $e");
      throw Exception("Failed to update trip");
    }
  }

  static Future<void> deleteTrip(String tripId) async {
    try {
      var collection = _db.collection('trips');
      await collection.deleteOne({'_id': ObjectId.fromHexString(tripId)});
    } catch (e) {
      print("Error deleting trip: $e");
      throw Exception("Failed to delete trip");
    }
  }
}
