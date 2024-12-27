import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';

// Cache manager with LRU (Least Recently Used)
class SearchCache {
  final int maxSize;
  final _cache = <String, List<SearchResult>>{};

  SearchCache({this.maxSize = 100});

  List<SearchResult>? get(String query) {
    final results = _cache[query];
    if (results != null) {
      // Move entry to the end (most recently used)
      _cache.remove(query);
      _cache[query] = results;
    }
    return results;
  }

  void set(String query, List<SearchResult> results) {
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first); // Remove least recently used
    }
    _cache[query] = results;
  }
}

// Realtime search widget
class RealtimeSearchWidget extends StatefulWidget {
  final Future<List<SearchResult>> Function(String query) onRemoteSearch;
  final String Function(String avatarUrl) fullUrlGetter;
  final Future<User?> Function(String friendUsername) addFriend;
  final void Function(User friend) addFriendToOtherWidget;
  final Duration debounceDuration = const Duration(milliseconds: 150);

  const RealtimeSearchWidget(
      {super.key,
      required this.onRemoteSearch,
      required this.fullUrlGetter,
      required this.addFriend,
      required this.addFriendToOtherWidget});

  @override
  State<RealtimeSearchWidget> createState() => _RealtimeSearchWidgetState();
}

class _RealtimeSearchWidgetState extends State<RealtimeSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final SearchCache _searchCache = SearchCache();
  List<SearchResult> _currentResults = [];
  List<SearchResult> _localResults = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

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
    logger.d('Search changed to $query');

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
      return result.user.username.toLowerCase().contains(query);
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
        final aExact = a.user.username.toLowerCase() == query;
        final bExact = a.user.username.toLowerCase() == query;
        if (aExact != bExact) return aExact ? -1 : 1;

        // Puis par score de pertinence
        return b.relevanceScore.compareTo(a.relevanceScore);
      });

      // Dédupliquer par ID
      final seen = <String>{};
      final uniqueResults =
          allResults.where((result) => seen.add(result.user.id)).toList();

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
    return Scaffold(
      appBar: AppBar(
        //return to friends list
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Rechercher un utilisateur'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur',
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
                      backgroundImage: NetworkImage(
                        widget.fullUrlGetter(result.user.avatarUrl),
                      ),
                      backgroundColor: Colors.grey[200],
                    ),
                    title: Text(result.user.username),
                    subtitle: Text(result.user.status),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Ajouter un ami'),
                                  content: const Text(
                                      'Voulez-vous ajouter cet utilisateur à votre liste d\'amis ?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Annuler'),
                                    ),
                                    TextButton(
                                      onPressed: () => {
                                        addFriend(result.user.username),
                                        Navigator.of(context).pop(),
                                      },
                                      child: const Text('Ajouter'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ));
              },
            ),
          ),
        ],
      ),
    );
  }

  // Ajouter un ami, TODO : faire l'implémentation total et voir avec leo pour plein de trucs
  Future<void> addFriend(String friend) async {
    try {
      User? friendAdded = await widget.addFriend(friend);
      if (friendAdded == null) {
        throw 'Utilisateur non trouvé ou Utilisateur déjà ajouté';
      } else {
        widget.addFriendToOtherWidget(friendAdded);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ami ajouté: ${friendAdded.username}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ajout: $e')),
      );
    }
  }
}
