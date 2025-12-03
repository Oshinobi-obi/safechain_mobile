
import 'package:flutter/material.dart';
import 'package:safechain/widgets/curved_app_bar.dart';

class CrimeScreen extends StatelessWidget {
  const CrimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CurvedAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Crime',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Crime',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This demonstration highlights how the SafeChain device strengthens personal safety by sending instant alerts during crime threats.',
            ),
            const SizedBox(height: 24),
            const Text(
              'Watch the demo here:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
