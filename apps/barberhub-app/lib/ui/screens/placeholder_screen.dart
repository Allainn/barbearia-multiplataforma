import 'package:flutter/material.dart';

import '../widgets/state_views.dart';

/// Aba ainda sem feature. Sai quando a tela de verdade entrar.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyView(icon: icon, title: 'Em construção', message: message),
    );
  }
}
