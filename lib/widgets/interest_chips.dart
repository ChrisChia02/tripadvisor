import 'package:flutter/material.dart';

class InterestChips extends StatefulWidget {
  final List<String> selected;
  final Function(List<String>) onChanged;

  static const List<String> allInterests = [
    'Adventure',
    'Beaches',
    'Cultural',
    'Food',
    'History',
    'Nature',
    'Nightlife',
    'Shopping',
    'Sightseeing',
    'Sports',
  ];

  const InterestChips({
    required this.selected,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  _InterestChipsState createState() => _InterestChipsState();
}

class _InterestChipsState extends State<InterestChips> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          InterestChips.allInterests.map((interest) {
            return FilterChip(
              label: Text(interest),
              selected: _selected.contains(interest),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selected.add(interest);
                  } else {
                    _selected.remove(interest);
                  }
                });
                widget.onChanged(_selected);
              },
            );
          }).toList(),
    );
  }
}
