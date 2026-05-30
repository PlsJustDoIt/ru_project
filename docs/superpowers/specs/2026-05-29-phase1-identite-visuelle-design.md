# Phase 1 — Identité visuelle & squelette de navigation

**Date :** 2026-05-29
**Type :** spec d'implémentation (Phase 1 de la [feuille de route](./2026-05-29-roadmap-ameliorations-appli-ru-design.md))
**Statut :** validée — prête pour le plan d'implémentation

---

## Objectif

Poser le **socle visuel et ergonomique** de l'appli avant les refontes fonctionnelles (chat Phase 2, menu Phase 3). C'est un chantier transversal : toutes les pages héritent de ce système de design et de cette navigation.

Décidé pendant le brainstorming (toutes les options ci-dessous ont été validées visuellement par l'utilisateur).

---

## 1. Nom de l'application

**MonCampus.**

- Remplace « Projet ru de léo » partout (AppBar/titre, `pubspec.yaml` nom + description, libellés, manifestes Android/iOS/web le cas échéant).
- Registre « campus / vie étudiante », direct et limpide pour un lancement.

---

## 2. Squelette de navigation — **option C : barre basse + « Plus »**

Remplace les 7 onglets *hauts* actuels (`TabBar` / `DefaultTabController` dans `tab_bar_widget.dart`) par une **barre de navigation basse** (Material 3 `NavigationBar`), accessible au pouce.

**5 entrées de la barre basse :**

| Slot | Destination | Note |
|------|-------------|------|
| 1 | 🗺️ Carte | secteurs / check-in |
| 2 | 🍽️ Menu | (refonte Phase 3) |
| 3 | 💬 Messages | ex-« Chat » (refonte Phase 2 — boîte de réception unifiée) |
| 4 | 👥 Amis | |
| 5 | ⋯ Plus | hub des destinations secondaires |

**L'écran « Plus » regroupe :** 👤 Profil · 🚌 Bus · ⚙️ Réglages · ↩️ Déconnexion.

**Justification :** Bus n'a pas de place naturelle dans « Profil » (ce que forcerait une barre à 5 destinations dont Profil) ; Profil/Bus/Réglages sont des destinations **occasionnelles** qui ne méritent pas un slot permanent ; « Plus » est **extensible** (toute future feature secondaire y atterrit sans retoucher la barre). Coût accepté : Profil à 2 taps au lieu d'1.

**Debug :** l'onglet Debug **disparaît de la vue de production**. En développement (`Config.env == "development"`), l'accès Debug peut vivre dans « Plus ».

---

## 3. Langage visuel — **direction A : sobre institutionnel**

Le rouge cesse d'être un aplat dominant (AppBar rouge actuelle) et devient un **accent maîtrisé**.

### Couleurs (jetons à définir dans `models/color.dart`)

| Rôle | Valeur | Usage |
|------|--------|-------|
| Accent / actions | `#E01020` | CTA, états actifs, éléments clés, ponctuation |
| Texte principal | `#1A2B3C` (bleu-nuit) | titres, corps |
| Texte secondaire | `#5A6573` | sous-titres, légendes |
| Surface | `#FFFFFF` | fond principal, AppBar |
| Fond groupé | `#F7F8FA` | zones/sections groupées |
| Bordures / filets | `#E3E6EA` | contours de cartes, séparateurs |
| Ambre | `#FFC107` | surlignage, **avec parcimonie** |
| Succès | `#1A7A3E` | sémantique |
| Erreur | `#B00020` | sémantique |

> Note : l'`AppColors` actuel (primary rouge plein, `textColor` blanc, etc.) est à remanier selon ces rôles. Les anciens usages « texte blanc sur fond rouge » disparaissent avec l'AppBar blanche.

### Typographie — Marianne (police déjà intégrée)

| Niveau | Taille | Graisse |
|--------|--------|---------|
| Titre | 21 | Bold |
| Section | 17 | Semibold |
| Corps | 15 | Regular |
| Légende | 12.5 | Regular (secondaire) |

### Composants partagés (à créer / harmoniser)

- **AppBar** : surface blanche, titre bleu-nuit, actions/icônes en accent rouge, élévation discrète (filet bas `#E3E6EA` plutôt qu'ombre lourde).
- **Cartes** : fond blanc, **filet fin** `#E3E6EA`, coins arrondis (~12 px), padding confortable. (Remplace les bordures épaisses de 3 px actuelles, ex. `menu_widget.dart`.)
- **Boutons primaires (CTA)** : fond rouge `#E01020`, texte blanc, coins arrondis (~10 px).
- **Barre basse** `NavigationBar` : item actif en rouge, inactifs en `#5A6573`.
- **État sélectionné / mise en avant** : surlignage rouge (ex. la carte « végé » du menu, le jour actif du bandeau).

### Échantillon validé

L'écran Menu rhabillé a servi de référence et a été validé (« j'adore ») : AppBar blanche au titre bleu-nuit, bandeau de jours (jour actif en rouge), cartes fines à filet, option végé surlignée, CTA rouge « On y mange ? ».

---

## Périmètre & limites

- **Dans le périmètre :** thème global (couleurs/typo/composants), bascule en barre de navigation basse (option C), renommage en MonCampus, retrait de Debug de la prod.
- **Hors périmètre (autres phases) :** la refonte fonctionnelle du Menu (Phase 3) et du Chat/Messages (Phase 2) — la Phase 1 fournit seulement le système de design qu'elles consommeront. Les écrans existants sont re-thémés *a minima* pour cohérence, sans refonte de leur logique.
- Le bug refresh web (ex-Phase 0) est traité séparément par l'utilisateur.

## Notes de référence (code)

- Navigation actuelle : `flutter/lib/widgets/tab_bar_widget.dart` (`DefaultTabController`, `TabBar`, 7 `Tab`).
- Thème : `flutter/lib/main.dart` (`ThemeData`, `ColorScheme`), `flutter/lib/models/color.dart` (`AppColors`).
- Écrans secondaires à regrouper sous « Plus » : `widgets/profile.dart`, `widgets/bus_widget.dart`, `widgets/settings_widget.dart`, `widgets/debug_widget.dart`.
- Nom/version : `flutter/lib/config.dart`, `flutter/pubspec.yaml`.
