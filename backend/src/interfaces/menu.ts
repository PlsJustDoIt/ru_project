/**
 * Menu d'un jour pour un resto, au format générique :
 * les catégories sont libres (Entrées, Plats du jour, Sandwichs,
 * "Soir — Plats du soir", ARSENAL...) selon la structure du flux CROUS.
 */
export interface Menu {
    date: string;
    plats: Record<string, string[]>;
}

export type MenuResponse = Menu | { fermeture: string; date: string };

// Type pour les objets <menu> du XML
export interface MenuXml {
    $: {
        date: string;
    };
    _: string; // Contenu HTML sous forme de chaîne
}
