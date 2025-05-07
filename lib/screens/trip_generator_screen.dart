import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../services/ai_service.dart';
import '../widgets/interest_chips.dart';
import '../widgets/date_range_picker.dart';
import 'trip_display_screen.dart';

class TripGeneratorScreen extends StatefulWidget {
  @override
  _TripGeneratorScreenState createState() => _TripGeneratorScreenState();
}

class _TripGeneratorScreenState extends State<TripGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController(text: '1000');
  DateTimeRange _dates = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(Duration(days: 3)),
  );
  List<String> _interests = [];
  int _travelers = 1;
  bool _isGenerating = false;

  // List of traveler options
  final List<int> _travelerOptions = List.generate(10, (index) => index + 1);

  Future<void> _generateTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isGenerating = true);

    try {
      final trip = await AIService.generateTrip(
        destination: _destinationController.text,
        startDate: _dates.start,
        endDate: _dates.end,
        interests: _interests,
        budget: double.parse(_budgetController.text),
        travelers: _travelers,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TripDisplayScreen(trip: trip)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating trip: $e')));
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Trip Planner')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _destinationController,
                decoration: InputDecoration(
                  labelText: 'Destination',
                  hintText: 'Where do you want to go?',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator:
                    (value) =>
                        value?.isEmpty ?? true
                            ? 'Please enter a destination'
                            : null,
              ),
              SizedBox(height: 20),
              DateRangePicker(
                initialRange: _dates,
                onChanged: (range) => setState(() => _dates = range),
              ),
              SizedBox(height: 20),

              // Dropdown for travelers selection
              DropdownButtonFormField<int>(
                value: _travelers,
                decoration: InputDecoration(
                  labelText: 'Number of Travelers',
                  prefixIcon: Icon(Icons.people),
                ),
                items:
                    _travelerOptions.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(
                          '$value ${value == 1 ? 'traveler' : 'travelers'}',
                        ),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _travelers = newValue;
                    });
                  }
                },
              ),

              SizedBox(height: 20),

              // Text field for budget input
              TextFormField(
                controller: _budgetController,
                decoration: InputDecoration(
                  labelText: 'Budget',
                  hintText: 'Enter your budget',
                  prefixIcon: Icon(Icons.monetization_on),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a budget';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),
              Text('Interests', style: Theme.of(context).textTheme.titleMedium),
              InterestChips(
                selected: _interests,
                onChanged:
                    (interests) => setState(() => _interests = interests),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isGenerating ? null : _generateTrip,
                child:
                    _isGenerating
                        ? CircularProgressIndicator()
                        : Text('Generate Trip Plan'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
