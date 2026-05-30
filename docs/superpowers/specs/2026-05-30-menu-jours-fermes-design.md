# Menu — jours fermés navigables

**Date :** 2026-05-30
**Statut :** validé (design)

## Problème

Sur l'onglet Menu, quand il n'y a pas de menu pour aujourd'hui (week-end, jour
férié, grève, RU fermé), l'app affiche une vue plein écran « Pas de menu
aujourd'hui » **sans le bandeau des jours**. L'utilisateur est dans un cul-de-sac :
impossible de naviguer vers les jours suivants qui, eux, ont un menu.

## Constat sur les données (API CROUS réelle, RU Lumière `r135`)

Le flux CROUS ne contient **que les jours ouverts**. Les jours fermés (week-ends,
fériés…) sont **purement absents** — il n'y a aucune balise ni marqueur de
fermeture pour eux. Exemple réel (aujourd'hui = samedi 30/05) : `2026-05-29` (ven)
puis saut direct à `2026-06-01` (lun) ; le 30, 31, 06, 07 n'existent pas.

Conséquences dans le code actuel :
- Backend (`ru.service.ts` / `ru.controller.ts`) : filtre `date >= today` et
  renvoie tels quels les jours du flux. Les trous restent des trous.
- Le champ `fermeture` du modèle (`extractFermeture`, déclenché seulement s'il y a
  **exactement un** `<h4>`) est **du code mort** sur les vraies données : les vrais
  menus ont plusieurs `<h4>`, donc un jour fermé n'arrive jamais comme `fermeture`.
- Flutter (`menu_widget.dart`) : construit le bandeau depuis la liste reçue. Si la
  liste est vide → plein écran sans bandeau. Si aujourd'hui est absent mais
  d'autres jours existent → le bandeau saute directement au premier jour ouvert,
  aucun message « pas de menu aujourd'hui ».

## Objectif

Le bandeau des jours est **toujours présent et navigable**. Tout jour sans menu
(trou dans le flux, y compris aujourd'hui) apparaît comme une chip « fermé » et
affiche, dans la page, la vue « Pas de menu » actuelle (icône + texte). On atterrit
sur aujourd'hui et on peut swiper vers les jours qui ont un menu.

## Décision d'architecture

Le comblement des trous se fait **côté backend** (choix validé). Avantages : tous
les clients en profitent, le champ `fermeture`/`isClosed()` (mort aujourd'hui)
reprend du sens, et c'est testable en Jest. Le frontend n'a qu'à afficher.

## Conception

### Backend

**`ru.service.ts` — nouvelle fonction pure `fillClosedDays(menus, today)`**
- Entrée : liste des jours ouverts (déjà filtrée `>= today`), et la date `today`
  (`YYYY-MM-DD`).
- Calcule `start = today`, `end = max(today, date du dernier menu)`.
- Pour chaque jour calendaire de `start` à `end` (itération en UTC, pour coller au
  `today` calculé via `toISOString`) :
  - si un menu existe pour cette date → on le garde tel quel (y compris un week-end,
    pour les RU ouverts le samedi : on ne masque jamais un menu réel) ;
  - sinon, **et seulement si ce n'est pas un samedi/dimanche** → on insère un jour
    fermé `{ date, fermeture: 'Restaurant fermé' }`.
- **Les week-ends ne sont jamais comblés** : ils sont toujours fermés, inutile de les
  afficher. Seules les fermetures **en semaine** (férié, grève) apparaissent comme
  « Pas de menu ».
- Liste vide un jour de semaine → un seul jour fermé `[{ date: today, fermeture }]`.
  Liste vide un week-end → `[]` (rien à afficher ; en pratique le flux réel a presque
  toujours des jours de semaine à venir).
- Tri défensif des entrées par date croissante.

**`ru.service.ts` — `fetchMenusFromExternalAPI`** ne filtre plus par date : il
renvoie **tous** les jours du flux. Le filtrage est une préoccupation d'affichage,
déplacée dans le controller (responsabilité unique + permet l'ancrage dev/prod).

**Ancrage `today` selon l'environnement (`isProduction`)**
- **Prod** : `today` = vraie date du jour → filtre `>= today` normal.
- **Dev** : `today` = **1er jour du fixture** (`menus.xml` est statique ; sinon tout
  serait filtré). On voit ainsi toujours une **semaine exemple** navigable. Fallback
  sur la vraie date si le fixture est vide.

**`ru.controller.ts` — `getMenus`**
- Unifier les deux branches (cache hit / miss) : récupérer la liste (cache ou
  `fetchMenusFromExternalAPI`), puis appliquer **par requête** `filtre date >= today`
  (avec le `today` ancré ci-dessus) puis `fillClosedDays(filtered, today)`.
- Le comblement n'est **pas** mis en cache (il dépend de `today`). Le cache continue
  de stocker la liste transformée brute.
- Effet de bord positif : supprime la duplication actuelle du filtre `>= today`
  présente dans les deux branches.

Le type `MenuResponse` accepte déjà la forme `{ date, fermeture }` (c'est ce que
`transformToMenu` renvoie pour un jour fermé), donc pas de changement de contrat de
type.

### Flutter (`menu_widget.dart` uniquement)

Aucun changement du modèle `Menu` : un jour fermé renvoyé par le backend a un
`fermeture` non nul, donc `Menu.fromJson` le mappe déjà en `isClosed() == true`.

- `build()` : supprimer le `if (_menus.isEmpty) return _noMenuView();` qui court-
  circuite tout. Toujours afficher `Column(_dayStrip, PageView, _eatHereBar)` basé
  sur `_menus`. `_noMenuView` reste utilisé comme simple fallback tant que `_menus`
  est vide (chargement / erreur initiale).
- `_dayView(menu)` : si `menu.isClosed()` → afficher la vue « Pas de menu » (le
  contenu actuel de `_noMenuView`, qui s'insère sans souci dans une page du
  `PageView`) ; sinon → cartes de catégories comme aujourd'hui.
- Le `_closedCard` au niveau jour est remplacé par cette vue. `_closedCard` reste
  utilisé pour le cas « jour ouvert mais menu non communiqué » (`_categoryCards`).
- Texte du placeholder rendu **générique** : titre « Pas de menu » au lieu de « Pas
  de menu aujourd'hui » (ça peut être n'importe quel jour). Sous-texte conservé
  (« Le RU est probablement fermé. »).
- La chip d'un jour fermé affiche normalement sa date via `_formatChip`.
  `_currentPage = 0` → on démarre sur aujourd'hui.

**Inchangé :** bouton « On y mange ? » (affiché aussi sur un jour fermé),
mécanique des chips et de la navigation `PageView`.

## Tests

- Backend (Jest, `fillClosedDays`) :
  - week-end intercalé entre deux semaines → **non inséré** (pas de chip sam/dim) ;
  - jour férié/grève en semaine absent → inséré en tête comme fermé ;
  - aujourd'hui = samedi → démarre au lundi suivant, aucune chip week-end ;
  - liste vide un jour de semaine → un seul jour fermé (aujourd'hui) ;
  - liste vide un week-end → `[]` ;
  - menu réel tombant un week-end → conservé (jamais masqué) ;
  - semaine pleine sans trou → liste inchangée (pas d'ajout) ;
  - pas de jour fermé ajouté **après** le dernier jour ouvert.
- Flutter : aucun test configuré dans le projet (non couvert).

## Hors périmètre

- Réactiver/corriger `extractFermeture` (code mort) — pas nécessaire pour ce besoin.
- Borne « fin de plage » au-delà du dernier jour du flux (pas de semaine fixe).
