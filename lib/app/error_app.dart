import 'package:flutter/material.dart';

class ErrorApp extends StatelessWidget {
  const ErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomohabits - Configuration Error',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const SelectableText(
                    'Pomohabits could not start',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(message),
                  const SizedBox(height: 16),
                  const SelectableText(
                    'Example: --dart-define=SUPABASE_URL=https://<ref>.supabase.co'
                    ' --dart-define=SUPABASE_PUBLISHABLE_KEY=<key>',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 12),
                  const SelectableText(
                    'See SETUP.md section 5 for the full env-var contract.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
