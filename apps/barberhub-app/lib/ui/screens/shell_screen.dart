import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../data/models/barbearia.dart';
import 'agendamentos_screen.dart';
import 'barbearia_detalhe_screen.dart';
import 'barbearias_screen.dart';
import 'conta_screen.dart';
import 'favoritos_screen.dart';

/// Estrutura do app: uma aba por área, com a barra de navegação embaixo.
///
/// Telas que abrem por cima (detalhe, reserva) usam `Navigator.push` a partir da aba.
/// O `IndexedStack` mantém o estado de cada aba ao trocar de aba (rolagem, busca digitada).
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  var _aba = 0;

  void _abrirDetalhe(Barbearia barbearia) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BarbeariaDetalheScreen(
          barbearia: barbearia,
          dependencies: widget.dependencies,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _aba,
        children: [
          BarbeariasScreen(
            controller: widget.dependencies.barbearias,
            favoritos: widget.dependencies.favoritos,
            onAbrir: _abrirDetalhe,
          ),
          FavoritosScreen(
            favoritos: widget.dependencies.favoritos,
            onAbrir: _abrirDetalhe,
            onVerBarbearias: () => setState(() => _aba = 0),
          ),
          AgendamentosScreen(
            controller: widget.dependencies.agendamentos,
            auth: widget.dependencies.auth,
            onVerBarbearias: () => setState(() => _aba = 0),
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
