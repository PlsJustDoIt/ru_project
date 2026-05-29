# Feuille de route — améliorations appli RU

**Date :** 2026-05-29
**Type :** feuille de route priorisée (multi-chantiers)
**Statut :** validée — à décomposer en specs/plans d'implémentation par chantier

---

## Contexte & cadre

L'appli RU (Flutter + backend Node/Express/TS + MongoDB) date un peu : visuel vieillissant, certaines fonctionnalités à moitié faites. Cette feuille de route fait le point sur les 7 onglets et fixe l'ordre des améliorations.

**Décisions de cadrage (validées avec l'utilisateur) :**

- **Statut projet :** lancement prévu prochainement (donc état de production visé).
- **Appétit d'effort :** rework en profondeur accepté (refactos lourds justifiés OK).
- **Direction visuelle :** **A — sobre institutionnel** (beaucoup de blanc, texte bleu-nuit, rouge `#E01020` en accent maîtrisé, ambre `#FFC107` secondaire, police Marianne, cartes fines). Crédible / « officiel », adapté à un lancement sérieux.
- **Rôle du chat :** fonctionnalité **importante mais pas centrale**.
- **Sécurité backend (AUDIT.md) :** **déjà corrigée** (commit `b20c9f9`) — vérifié : plus de repli `'truc'`, CORS configuré, regex de recherche échappée (`escapeRegExp`), secrets validés au démarrage (`requireEnv`), serveur HTTPS réintroduit. **Ce n'est donc pas un chantier**, juste une revérification ponctuelle avant lancement.

**Méthode :** chaque phase ci-dessous donnera lieu à son propre cycle spec → plan → implémentation. Cette feuille de route en fixe l'ordre et le périmètre.

---

## Séquence (vue d'ensemble)

L'ordre suit les dépendances : le bug bloquant d'abord, puis le thème (socle transversal dont chat et menu héritent), puis les deux gros chantiers fonctionnels, puis la finition.

| Phase | Chantier | Effort | Note | Statut |
|------|----------|--------|------|--------|
| 0 | Bug refresh web | S–M | Bloquant de lancement | ✅ fait |
| 1 | Identité visuelle (thème direction A) | M | Socle transversal | ✅ fait |
| 2 | Chat (refonte + vocal) | L | Cœur de la demande | 🟡 2a fait — 2b/2c/2d à venir |
| 3 | Menu (refonte + social) | M | « Mieux exploité » | ⬜ à faire |
| 4 | Polish & dette | M | Finition | ⬜ à faire |

---

## Phase 0 — Bug refresh web *(bloquant de lancement)*

**Problème :** sur la version web, un rafraîchissement (F5) déconnecte l'utilisateur.

**Diagnostic réalisé :**
- `flutter_secure_storage 9.2.4`, **aucune config `WebOptions`** dans le code.
- L'intercepteur Dio (`api_client.dart`) rafraîchit sur 401/403 puis déconnecte si `/auth/token` échoue.
- `UserProvider.init()` (appelé dans `main()` avant `runApp`) lit l'access token, appelle `getUser()`, et `clearUserData()` en cas d'échec.

**Cause probable :** persistance des tokens sur web (comportement de `flutter_secure_storage` côté navigateur / `WebOptions`) ou chemin de refresh de l'intercepteur sur web. **À reproduire pour trancher.**

**Périmètre :** bug ciblé et borné. *Effort : S–M.*

---

## Phase 1 — Identité visuelle *(socle transversal)*

À faire tôt : les refontes chat (Phase 2) et menu (Phase 3) seront construites sur ce système de design.

**À livrer :**
- Thème global **direction A** : palette rouge/ambre/blanc assainie + texte bleu-nuit ; typo Marianne ; composants partagés (cartes fines, boutons, AppBar).
- Renommer « Projet ru de léo » → vrai nom de l'app.
- Sortir l'onglet **Debug** de la vue de production (aujourd'hui conditionné à `Config.env == "development"` mais à confirmer dans la nouvelle navigation).

*Effort : M.*

---

## Phase 2 — Chat *(gros chantier — cœur de la demande)*

**État actuel :** le Global est un onglet ; les chats privés sont accessibles depuis l'onglet Amis (icône 💬, ouvre un `ChatWidget` plein écran). Chaque `ChatUi` **ouvre sa propre socket** en `initState` et la ferme en `dispose`. Conséquences : reconnexion + spinner « Chargement… » à chaque écran ; l'appli est **aveugle** aux messages des autres rooms dès qu'on change d'écran (aucune notif/pastille possible). Bugs résiduels dans `ChatUi` : auteurs affichés « John Doe » (`resolveUser` bouchonné), fallback texte *lorem ipsum* aléatoire, vocal stubbé.

**Cible : boîte de réception unifiée (option A).** L'onglet Chat devient une **liste de conversations** : Global épinglé en haut + une ligne par ami (aperçu du dernier message, horodatage, point de présence). Tap → ouvre la conversation. Le vrai gain structurel est la **socket unique persistante**, qui rend l'appli consciente des messages partout.

**Vérification technique faite :** `flutter_chat_ui 2.11.1` / `flutter_chat_core 2.9.0` **ne fournissent pas** de bouton micro intégré (seulement un `composer` + `onAttachmentTap`). Le type `AudioMessage` existe pour l'affichage (via `AudioPlayerWidget` déjà présent), mais **l'enregistrement et son UX sont à notre charge**.

**Sous-chantiers (ordre recommandé) :**
- **2a — Socle :** ✅ **FAIT** (branche `feat/phase2a-socle-socket`, fusionnée dans `dev`). Socket **unique persistante** extraite de `ChatUi` vers le service dédié `ChatConnection` (ouverte au login, fermée au logout, survit aux changements d'écran) + **un seul composant `ChatUi`** paramétré par room ; `ChatWidget` supprimé. Bugs corrigés : jointure de room privée (Map → tableau de 2), « John Doe », fallback *lorem* ; hack vocal retiré (revient en 2d) ; dépendances mortes retirées. Spec : `specs/2026-05-29-phase2a-socle-socket-design.md` ; plan : `plans/2026-05-29-phase2a-socle-socket.md`. *Reste à valider : test manuel temps-réel à 2 comptes (Task 7 du plan).*
- **2b — Boîte de réception unifiée :** nouvel écran liste de conversations (Global + amis, aperçus/horodatage). Backend : endpoint « résumé des conversations ».
- **2c — Notifs in-app** *(appli ouverte, débloqué par la socket persistante, coût faible)* : pastille sur l'onglet Messages, compteur de non-lus par conversation, bandeau « X t'a écrit », son/vibration légère.
- **2d — Vocal complet :** bouton micro propre (appui-maintien) + **upload** + **stockage backend** + lecture pour tous les participants. Remplace le hack actuel (délai fixe 8 s, pas d'upload).

**Plus tard / optionnel (ne bloque pas le lancement) :**
- Non-lus persistés (`lastReadAt` par room côté backend) — la pastille de la liste sans persistance est faisable en MVP.
- **Push système** (téléphone verrouillé / appli fermée) : nécessite **FCM (Android) + APNs (iOS) + Web Push** et la gestion de « device tokens » côté backend. **Chantier lourd à part entière.** La socket ne couvre PAS ce cas (elle meurt en arrière-plan).

*Effort global : L.*

---

## Phase 3 — Menu *(« mieux exploité »)*

**Données disponibles (flux CROUS) :** par jour, des **catégories** (Entrées, Cuisine traditionnelle, Menu végétalien, Pizza, Cuisine italienne, Grill), chacune = liste de noms de plats ; plus des messages de fermeture. **Non disponible :** pas de dîner (déjeuner seulement), pas de prix, pas d'allergènes, pas de photos, pas de nutrition. Toute idée nécessitant ces données est écartée (pas de source).

**État actuel :** affiche toutes les catégories d'un jour ; navigation par flèches ‹ › pour changer de jour ; déco basique (bordures épaisses, TODO « à revoir »). Besoin clé exprimé : **voir les repas de la semaine à l'avance** (la navigation flèche-par-flèche est lente pour ça). *À vérifier : une ligne du code (`menu_widget.dart`, condition `key == "Entrées"`) saute les entrées — confirmer qu'elle ne masque rien d'utile.*

**À livrer :**
- Refonte « coup d'œil » direction A : toutes les catégories d'un jour en **cartes + icônes**, lisibles d'un coup.
- Navigation **bandeau de jours + jour détaillé** (option A retenue) : rangée de jours cliquables en haut, jour choisi affiché en entier dessous (+ swipe). Saut direct à n'importe quel jour pour voir la semaine à l'avance.
- **Accroche sociale :** depuis un menu, « on y mange ? » → passe le statut à *au ru* et/ou prévient les amis / poste dans le Global. Relie menu ↔ secteurs ↔ chat (c'est le sens de « mieux exploité »).

*Effort : M.*

---

## Phase 4 — Polish & dette *(finition)*

- **Carte / secteurs :** supprimer les widgets carte morts (`old_map_widget_2`, `chatgpt_map_widget`, `old_map_widget`, etc.), clarifier l'UX du check-in.
- **Amis :** corriger les `use_build_context_synchronously` (risque de crash réel : `auth_form.dart`, `friends_request_widget.dart`, `friends_widget.dart`), icône d'onglet cohérente (aujourd'hui `Icons.fiber_new`).
- **Nettoyage :** supprimer le code mort (`web_socket_service.dart`, `cache_service.dart`, vieux maps, `menu_provider.dart` non câblé) ; `dart fix --apply` (≈55 warnings `flutter analyze`) ; résoudre les erreurs ESLint backend.
- **Profil & Bus :** polish visuel hérité du thème (pas de manque fonctionnel).

*Effort : M.*

---

## Hors périmètre (assumé)

- **Allergènes / nutrition / prix / dîner au menu** : non fournis par le flux CROUS, écartés faute de source.
- **Push notifications système** : chantier lourd séparé, optionnel, post-lancement.
- **Profil & Bus en tant que refonte fonctionnelle** : seulement du polish visuel.

---

## Notes de référence (code)

- Chat : `flutter/lib/widgets/chat_ui.dart`, `chat_widget.dart` ; socket : `flutter/lib/services/socket_service.dart` ; entrée chat privé : `friends_widget.dart:282`.
- Menu : `flutter/lib/widgets/menu_widget.dart` (condition `Entrées` ~ligne 232) ; modèle `flutter/lib/models/menu.dart` ; backend `backend/src/routes/ru/ru.service.ts`.
- Refresh web : `flutter/lib/services/secure_storage.dart`, `api_client.dart`, `flutter/lib/main.dart` (`UserProvider.init`), `flutter/lib/config.dart`.
- Thème : `flutter/lib/models/color.dart`, `flutter/lib/main.dart` (`ThemeData`).
