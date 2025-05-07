import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangePicker extends StatelessWidget {
  final DateTimeRange initialRange;
  final Function(DateTimeRange) onChanged;

  const DateRangePicker({
    required this.initialRange,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDateRange: initialRange,
    );

    if (picked != null && picked != initialRange) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return InkWell(
      onTap: () => _selectDateRange(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Trip Dates',
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(dateFormat.format(initialRange.start)),
            Icon(Icons.arrow_forward, color: Colors.grey),
            Text(dateFormat.format(initialRange.end)),
          ],
        ),
      ),
    );
  }
}
