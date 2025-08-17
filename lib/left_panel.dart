// left_panel.dart
import 'package:flutter/material.dart';

class LeftPanel extends StatelessWidget {
  // You might pass in callbacks or data here if needed
  final VoidCallback? onOpenSettings;

  const LeftPanel({super.key, this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[100], // Example background color
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start, // Align to top
        crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch horizontally
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Navigation & Controls',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Dashboard'),
            onTap: () {
              // Handle navigation to Dashboard
            },
          ),
          ListTile(
            title: const Text('Sessions List'),
            onTap: () {
              // Handle navigation to Sessions List
            },
          ),
          const Spacer(), // Pushes content to the top
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: onOpenSettings, // Use the passed callback
              child: const Text('Open Settings'),
            ),
          ),
        ],
      ),
    );
  }
}
