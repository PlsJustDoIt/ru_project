import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';

class TransportTimeWidget extends StatefulWidget {
  const TransportTimeWidget({super.key});

  @override
  State<TransportTimeWidget> createState() => _TransportWidgetState();
}

class _TransportWidgetState extends State<TransportTimeWidget> {
  Stream<Map<String, dynamic>>? _horairesStream;
  bool _isActive = true; // Contrôle pour arrêter le flux
  @override
  void initState() {
    super.initState();
    _horairesStream = _createHorairesStream();
  }

  @override
  void dispose() {
    super.dispose();
    _isActive = false;
    // _horairesStream = null; // Stopper le flux
  }

  Stream<Map<String, dynamic>> _createHorairesStream() async* {
    final apiService = Provider.of<ApiService>(context, listen: false);

    while (_isActive) {
      // S'assurer que le flux continue seulement si actif
      try {
        final data = await apiService.getHoraires();
        logger.i('Données reçues : $data');
        yield data;
      } catch (e) {
        yield {'error': 'Erreur : $e'};
      }

      await Future.delayed(
          Duration(minutes: 1)); // Délai de 1 minute entre les requêtes
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _horairesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.blue[800],
            ),
          );
        }

        if (snapshot.hasError || snapshot.data?['error'] != null) {
          return Card(
            color: Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Erreur de chargement : ${snapshot.data?['error'] ?? snapshot.error}',
                style: TextStyle(color: Colors.red[800]),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Aucune donnée disponible',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        final transportData = snapshot.data!;
        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transportData['nomExact'] ?? 'Transport Times',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 16),
                if (transportData['lignes'] != null)
                  ...transportData['lignes'].entries.map((lineEntry) {
                    return _buildLineSection(lineEntry.key, lineEntry.value);
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _buildLineSection(String lineNumber, Map<String, dynamic> destinations) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Ligne $lineNumber',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.blue[600],
          ),
        ),
      ),
      ...destinations.entries.map((destinationEntry) {
        return _buildDestinationRow(
            destinationEntry.key, destinationEntry.value);
      }),
      const Divider(height: 16, thickness: 1),
    ],
  );
}

Widget _buildDestinationRow(String destination, List<dynamic> times) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            destination,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: times
                .map((time) => Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          time,
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    ),
  );
}
