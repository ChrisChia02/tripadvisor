import 'package:flutter/material.dart';
import 'package:path/path.dart';
import '../models/trip.dart';
import 'package:intl/intl.dart';
import '/mongodb.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripDisplayScreen extends StatelessWidget {
  final Trip trip;

  const TripDisplayScreen({required this.trip, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Build a Trip with AI'),
        backgroundColor: Colors.blue[300],
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTripHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: trip.itinerary.length,
              itemBuilder: (context, index) {
                final day = trip.itinerary[index];
                // Combine all activities for the day into a single list
                final allActivities = [
                  ...day.morning,
                  ...day.afternoon,
                  ...day.evening,
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDayHeader(day, context),
                    ...List.generate(allActivities.length, (activityIndex) {
                      return _buildActivityItem(
                        activityIndex + 1,
                        allActivities[activityIndex],
                        isExpanded: true, // Changed to show all details
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          _buildSaveButton(context),
        ],
      ),
    );
  }

  Widget _buildTripHeader() {
    final dateFormat = DateFormat('EEEE, d MMM');
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your trip in ${trip.destination}',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            'for ${trip.duration} days.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            dateFormat.format(trip.startDate),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(DayItinerary day, BuildContext context) {
    // Assuming the day number would be shown here
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Day ${day.dayNumber}',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActivityItem(
    int activityNumber,
    Activity activity, {
    bool isExpanded = false,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
                child: Center(
                  child: Text(
                    '$activityNumber',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            activity.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow:
                                TextOverflow.ellipsis, // Truncate long text
                            maxLines: 1, // Limit to one line
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                        ),
                      ],
                    ),
                    if (activity.location.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.place, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                activity.location,
                                style: TextStyle(color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isExpanded) ...[
                      SizedBox(height: 8),
                      if (activity.imageUrl != null &&
                          activity.imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            activity.imageUrl!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < 4 ? Icons.star : Icons.star_half,
                                size: 16,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text('242', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        activity.description,
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      GestureDetector(
                        child: Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              ' ',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          // Show operating hours
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please sign in to save trips')),
          );
          return;
        }

        try {
          // Convert AI-generated trip itinerary to database format
          List<Map<String, dynamic>> formattedItinerary = [];

          for (var day in trip.itinerary) {
            // Combine all activities for the day
            final allActivities = [
              ...day.morning,
              ...day.afternoon,
              ...day.evening,
            ];

            for (var activity in allActivities) {
              formattedItinerary.add({
                'place': {
                  'id':
                      'place_${DateTime.now().millisecondsSinceEpoch}_${activity.title.hashCode}',
                  'name': activity.title,
                  'type': activity.type,
                  'destination': trip.destination,
                  'imageUrl': activity.imageUrl,
                  'rating': 4.0, // Default rating (as in sample trips)
                  'reviewCount':
                      242, // Default review count (as in sample trips)
                },
                'date':
                    trip.startDate
                        .add(Duration(days: day.dayNumber - 1))
                        .toIso8601String(),
                'arrivalTime': _estimateArrivalTime(
                  allActivities.indexOf(activity),
                ), // Estimate time
                'notes': activity.description,
              });
            }
          }

          // Save to MongoDB
          await MongoDatabase.saveTrip(user.uid, {
            'name': 'Trip to ${trip.destination}',
            'itinerary': formattedItinerary,
            'isSample': false, // Mark as non-sample trip
            'createdAt': DateTime.now(),
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Trip saved successfully!')));

          print('Trip saved!');
          Navigator.popUntil(context, (route) => route.isFirst);
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save trip: $e')));
          print('Error saving trip: $e');
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        color: Colors.blue[400],
        child: Center(
          child: Text(
            'Save itinerary',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to estimate arrival times for activities
  String _estimateArrivalTime(int activityIndex) {
    // Simple time estimation based on activity index
    const List<String> times = ['09:00', '12:00', '14:00', '18:00'];
    return times[activityIndex % times.length];
  }
}
