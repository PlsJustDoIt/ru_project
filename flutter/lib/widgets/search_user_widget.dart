import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/searchResult.dart';

// TODO
class LocalSearchDB {
  final List<SearchResult> _items = [];
  final int maxItems;

  LocalSearchDB({this.maxItems = 1000});

  void addItem(SearchResult item) {
    if (_items.length >= maxItems) {
      _items.removeAt(0);
    }
    if (!_items.any((element) => element.user.id == item.user.id)) {
      _items.add(item);
    }
  }

  void addItems(List<SearchResult> items) {
    for (var item in items) {
      addItem(item);
    }
  }

  List<SearchResult> search(String query) {
    if (query.isEmpty) return [];

    return _items.where((item) {
      final username = item.user.username.toLowerCase();
      final searchQuery = query.toLowerCase();

      // Score de pertinence amélioré
      if (username.startsWith(searchQuery)) {
        item.relevanceScore = 1.0;
      } else if (username.contains(searchQuery)) {
        item.relevanceScore = 0.5;
      } else {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
  }

  void clear() => _items.clear();
  int get size => _items.length;
}

class PlatformAdaptiveCache {
  final int cacheMaxSize;
  final Duration timeToLive;
  final Map<String, CacheEntry<List<SearchResult>>> _memoryCache = {};
  bool _isInitialized = false;

  static const String _cacheKey = 'search_cache';
  late final Directory? _cacheDir;

  PlatformAdaptiveCache({
    this.cacheMaxSize = 50,
    this.timeToLive = const Duration(minutes: 30),
  });

  Future<void> init() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      final appCacheDir = await getApplicationCacheDirectory();
      _cacheDir = Directory(path.join(appCacheDir.path, 'search_cache'));
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
    }

    await _loadCache();
    _isInitialized = true;
  }

  Future<void> _loadCache() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final String? cachedData = prefs.getString(_cacheKey);
        if (cachedData != null) {
          final Map<String, dynamic> data = json.decode(cachedData);
          _loadCacheData(data);
        }
      } else {
        final cacheFile = File(path.join(_cacheDir!.path, 'cache.json'));
        if (await cacheFile.exists()) {
          final String contents = await cacheFile.readAsString();
          final Map<String, dynamic> data = json.decode(contents);
          _loadCacheData(data);
        }
      }
    } catch (e) {
      // En cas d'erreur, on nettoie le cache
      await clear();
    }
  }

  void _loadCacheData(Map<String, dynamic> data) {
    data.forEach((key, value) {
      final entry = CacheEntry<List<SearchResult>>.fromJson(value);
      if (_isExpired(entry) == false) {
        _memoryCache[key] = entry;
      }
    });
  }

  Future<void> _saveCache() async {
    final Map<String, dynamic> data = {};
    _memoryCache.forEach((key, value) {
      if (!_isExpired(value)) {
        data[key] = value.toJson();
      }
    });

    final String encodedData = json.encode(data);

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, encodedData);
    } else {
      final cacheFile = File(path.join(_cacheDir!.path, 'cache.json'));
      await cacheFile.writeAsString(encodedData);
    }
  }

  Future<List<SearchResult>?> getUsersFromCache(String query) async {
    if (!_isInitialized) await init();

    final entry = _memoryCache[query];
    if (entry == null || _isExpired(entry)) {
      _memoryCache.remove(query);
      await _saveCache();
      return null;
    }

    // Déplacer à la fin pour le comportement LRU
    _memoryCache.remove(query);
    _memoryCache[query] = entry;
    return entry.data;
  }

  Future<void> addUsersToCache(String query, List<SearchResult> results) async {
    if (!_isInitialized) await init();

    if (_memoryCache.length >= cacheMaxSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }

    _memoryCache[query] = CacheEntry(results);
    await _saveCache();
  }

  bool _isExpired(CacheEntry entry) {
    return DateTime.now().difference(entry.timestamp) > timeToLive;
  }

  Future<void> clear() async {
    _memoryCache.clear();

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } else {
      if (await _cacheDir!.exists()) {
        await _cacheDir.delete(recursive: true);
        await _cacheDir.create(recursive: true);
      }
    }
  }
}

class CacheEntry<T> {
  final T data;
  DateTime timestamp;

  CacheEntry(this.data) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'data': data, // Assurez-vous que T peut être sérialisé en JSON
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      json['data'] as T,
    )..timestamp = DateTime.parse(json['timestamp'] as String);
  }
}

// Realtime search widget
class RealtimeSearchWidget extends StatefulWidget {
  final Future<List<SearchResult>> Function(String query) onRemoteSearch;
  final String Function(String avatarUrl) getImageNetworkUrl;
  final Future<User?> Function(String friendUsername) addFriend;
  final void Function(User friend) addFriendToFriendsList;
  final Duration debounceDuration = const Duration(milliseconds: 250);

  const RealtimeSearchWidget(
      {super.key,
      required this.onRemoteSearch,
      required this.getImageNetworkUrl,
      required this.addFriend,
      required this.addFriendToFriendsList});

  @override
  State<RealtimeSearchWidget> createState() => _RealtimeSearchWidgetState();
}

class _RealtimeSearchWidgetState extends State<RealtimeSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  late final PlatformAdaptiveCache _searchCache;
  List<SearchResult> _currentResults = [];
  List<SearchResult> _localResults = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  // Simuler une base de données locale
  final _localDb = LocalSearchDB();

  @override
  void initState() {
    super.initState();
    _searchCache = PlatformAdaptiveCache();
    _searchCache.init();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final String query = _searchController.text.toLowerCase().trim();
    logger.d('Search changed to $query');

    // 1. Recherche immédiate dans les données locales
    _performLocalSearch(query);

    // si deja cache alors on ne fait pas la recherche distante

    // 2. Debounce pour la recherche distante
    _debounceTimer?.cancel();
    if (query.length >= 3) {
      _debounceTimer = Timer(widget.debounceDuration, () {
        _performRemoteSearch(query);
      });
    } else {
      setState(() {
        _currentResults = _localResults;
      });
    }
  }

  Future<void> _performLocalSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _localResults = [];
        _currentResults = [];
      });
      return;
    }

    // Recherche dans le cache d'abord
    final cachedResults = await _searchCache.getUsersFromCache(query);
    if (cachedResults != null) {
      setState(() {
        _currentResults = cachedResults;
      });
      return;
    }

    // Sinon, recherche dans la base locale
    _localResults = _localDb.search(query);
    setState(() {
      _currentResults = _localResults;
    });
  }

  Future<void> _performRemoteSearch(String query) async {
    try {
      setState(() {
        //TODO : a voir si c'est bien
        _isLoading = true;
      });

      final remoteResults = await widget.onRemoteSearch(query);

      // Fusionner et trier les résultats
      final allResults = [..._localResults, ...remoteResults];
      allResults.sort((a, b) {
        return b.relevanceScore.compareTo(a.relevanceScore);
      });

      // Dédupliquer par ID
      final seen = <String>{};
      final uniqueResults =
          allResults.where((result) => seen.add(result.user.id)).toList();

      // Mettre en cache
      _searchCache.addUsersToCache(query, uniqueResults);

      //mettre à dans la base locale
      _localDb.addItems(uniqueResults);

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
              //textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel),
                        iconSize: 30,
                        onPressed: _searchController.clear,
                      )
                    : null,
              ),
              onChanged: (_) => _onSearchChanged(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_currentResults.isEmpty &&
                        _searchController.text.length >= 3)
                    ? const Center(
                        child: Text(
                            'Aucun résultat')) //TODO : a faire correctement
                    : ListView.builder(
                        itemCount: _currentResults.length,
                        itemBuilder: (context, index) {
                          final result = _currentResults[index];
                          return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(
                                  widget.getImageNetworkUrl(
                                      result.user.avatarUrl),
                                ),
                                backgroundColor: Colors.grey[200],
                              ),
                              title: Text(result.user.username),
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
                                                  addFriend(
                                                      result.user.username),
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

  // Ajouter un ami
  Future<void> addFriend(String friend) async {
    try {
      User? friendAdded = await widget.addFriend(friend);
      if (friendAdded == null) {
        throw 'Utilisateur non trouvé ou Utilisateur déjà ajouté';
      } else {
        widget.addFriendToFriendsList(friendAdded);
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
