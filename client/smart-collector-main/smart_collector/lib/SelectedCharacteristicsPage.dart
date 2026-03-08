import 'package:flutter/material.dart';

import 'globals.dart';
import 'chartCartesianPage.dart';

class SelectedCharacteristicsPage extends StatelessWidget {
  final Globals globals;

  /// Mappa characteristicId -> serviceId
  final Map<String, String> selected;

  const SelectedCharacteristicsPage({
    Key? key,
    required this.globals,
    required this.selected,
  }) : super(key: key);

  String _norm(String s) => s.trim().toLowerCase();

  String _charName(String charId) {
    return globals.characteristicNames[_norm(charId)] ?? 'Unknown Characteristic';
  }

  bool _isGsrFamily(String charId) {
    final c = _norm(charId);
    return c == _norm(globals.gsrCharacteristicId) ||
        c == _norm(globals.tonCharacteristicId) ||
        c == _norm(globals.fasCharacteristicId);
  }

  @override
  Widget build(BuildContext context) {
    final entries = selected.entries.toList()
      ..sort((a, b) => _charName(a.key).compareTo(_charName(b.key)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selected measurements'),
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No measurements selected.'))
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final charId = entries[index].key;
                final serviceId = entries[index].value;

                return ListTile(
                  title: Text(_charName(charId)),
                  trailing: const Icon(Icons.show_chart),
                  onTap: () {
                    final isGsrTrio = _isGsrFamily(charId);

                    final chartIds = isGsrTrio
                        ? <String>[
                            globals.gsrCharacteristicId,
                            globals.tonCharacteristicId,
                            globals.fasCharacteristicId,
                          ]
                        : <String>[charId];

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChartCartesianPage(
                          globals: globals,
                          serviceId: serviceId, // stesso servizio, come hai detto
                          characteristicId: charId,
                          title: _charName(charId),
                          chartCharacteristicIds: chartIds, 
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
