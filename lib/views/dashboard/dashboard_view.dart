import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => context.push('/dashboard/profile'),
              child: const Text('Go to Profile'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/dashboard/my-courses'),
              child: const Text('My Courses'),
            ),
          ],
        ),
      ),
    );
  }
}
