import 'package:flutter/material.dart';
import 'dart:async';

// Modèle de résultat de recherche avec score de pertinence
class SearchResult {
  final String id;
  final String name;
  final String photoUrl;
  final double relevanceScore;
  final String type; // 'friend', 'group', 'page', etc.

  SearchResult({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.relevanceScore,
    required this.type,
  });
}

// Gestionnaire de cache avec LRU (Least Recently Used)
class SearchCache {
  final int maxSize;
  final _cache = <String, List<SearchResult>>{};

  SearchCache({this.maxSize = 100});

  List<SearchResult>? get(String query) {
    final results = _cache[query];
    if (results != null) {
      // Déplacer l'entrée à la fin (plus récemment utilisée)
      _cache.remove(query);
      _cache[query] = results;
    }
    return results;
  }

  void set(String query, List<SearchResult> results) {
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first); // Supprimer le moins récemment utilisé
    }
    _cache[query] = results;
  }
}

class RealtimeSearchWidget extends StatefulWidget {
  final Future<List<SearchResult>> Function(String query) onRemoteSearch;
  final Duration debounceDuration;

  const RealtimeSearchWidget({
    Key? key,
    required this.onRemoteSearch,
    this.debounceDuration = const Duration(milliseconds: 150),
  }) : super(key: key);

  @override
  State<RealtimeSearchWidget> createState() => _RealtimeSearchWidgetState();
}

class _RealtimeSearchWidgetState extends State<RealtimeSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  final SearchCache _searchCache = SearchCache();
  List<SearchResult> _currentResults = [];
  List<SearchResult> _localResults = [];
  bool _isLoading = false;
  
  // Simuler une base de données locale
  final List<SearchResult> _localDb = [
    // Amis récents, favoris, contacts fréquents, etc.
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    
    // 1. Recherche immédiate dans les données locales
    _performLocalSearch(query);

    // 2. Debounce pour la recherche distante
    _debounceTimer?.cancel();
    if (query.length >= 2) {
      _debounceTimer = Timer(widget.debounceDuration, () {
        _performRemoteSearch(query);
      });
    } else {
      setState(() {
        _currentResults = _localResults;
      });
    }
  }

  void _performLocalSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _localResults = [];
        _currentResults = [];
      });
      return;
    }

    // Recherche dans le cache d'abord
    final cachedResults = _searchCache.get(query);
    if (cachedResults != null) {
      setState(() {
        _currentResults = cachedResults;
      });
      return;
    }

    // Sinon, recherche dans la base locale
    _localResults = _localDb.where((result) {
      // Algorithme de recherche locale simple
      return result.name.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    setState(() {
      _currentResults = _localResults;
    });
  }

  Future<void> _performRemoteSearch(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final remoteResults = await widget.onRemoteSearch(query);
      
      // Fusionner et trier les résultats
      final allResults = [..._localResults, ...remoteResults];
      allResults.sort((a, b) {
        // Priorité aux correspondances exactes
        final aExact = a.name.toLowerCase() == query;
        final bExact = b.name.toLowerCase() == query;
        if (aExact != bExact) return aExact ? -1 : 1;
        
        // Puis par score de pertinence
        return b.relevanceScore.compareTo(a.relevanceScore);
      });

      // Dédupliquer par ID
      final seen = <String>{};
      final uniqueResults = allResults.where((result) => 
        seen.add(result.id)).toList();

      // Mettre en cache
      _searchCache.set(query, uniqueResults);

      if (mounted) {
        setState(() {
          _currentResults = uniqueResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Rechercher',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _searchController.clear,
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _currentResults.length,
            itemBuilder: (context, index) {
              final result = _currentResults[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(result.photoUrl),
                  backgroundColor: Colors.grey[200],
                ),
                title: Text(result.name),
                subtitle: Text(result.type),
                trailing: result.type == 'friend'
                    ? const Icon(Icons.person_outline)
                    : result.type == 'group'
                        ? const Icon(Icons.group_outlined)
                        : const Icon(Icons.public),
              );
            },
          ),
        ),
      ],
    );
  }
}