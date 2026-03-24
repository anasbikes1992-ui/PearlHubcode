import 'package:flutter/material.dart';

class PlaceholderScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? child;
  final List<Widget>? actions;

  const PlaceholderScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}
