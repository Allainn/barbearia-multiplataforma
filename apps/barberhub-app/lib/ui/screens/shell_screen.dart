import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import 'barbearias_screen.dart';
import 'conta_screen.dart';
import 'placeholder_screen.dart';

/// Estrutura do app: uma aba por área, com a barra de navegação embaixo.
///
/// Cada feature troca o `PlaceholderScreen` da sua aba pela tela de verdade. Telas que
/// abrem por cima (detalhe, reserva) usam `Navigator.push` a partir da aba.
/// O `IndexedStack` mantém o estado de cada aba ao trocar de aba (rolagem, busca digitada).
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  var _aba = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _aba,
        children: [
          BarbeariasScreen(controller: widget.dependencies.barbearias),
          const PlaceholderScreen(
            title: 'Favoritos',
            icon: Icons.favorite_outline,
            message:
                'As barbearias marcadas com o coração aparecem aqui e continuam '
                'salvas depois de fechar o app (feature 6).',
          ),
          const PlaceholderScreen(
            title: 'Agendamentos',
            icon: Icons.event_note_outlined,
            message:
                'Suas reservas e o cancelamento entram aqui (feature 8). A reserva '
                'começa no detalhe da barbearia (feature 7).',
          ),
          ContaScreen(
            config: widget.dependencies.config,
            themeController: widget.dependencies.theme,
            auth: widget.dependencies.auth,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (aba) => setState(() => _aba = aba),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Barbearias',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Agendamentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Conta',
          ),
        ],
      ),
    );
  }
}
