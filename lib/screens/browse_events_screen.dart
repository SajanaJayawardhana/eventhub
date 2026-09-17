import 'package:flutter/material.dart';

class BrowseEventsScreen extends StatelessWidget {
  const BrowseEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore, size: 64, color: Colors.deepPurple),
          SizedBox(height: 16),
          Text(
            'Browse Events',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Discover amazing events near you.'),
        ],
      ),
    );
  }
}
