export interface Menu {
    'Entrées': string[] | 'menu non communiqué';
    'Cuisine traditionnelle': string[] | 'menu non communiqué';
    'Menu végétalien': string[] | 'menu non communiqué';
    'Pizza': string[] | 'menu non communiqué';
    'Cuisine italienne': string[] | 'menu non communiqué';
    'Grill': string[] | 'menu non communiqué';
    'Fermeture': string; // Date de fermeture si il y en a une sinon false
    'date': string;
}

// Type pour les objets <menu> du XML
export interface MenuXml {
    $: {
        date: string;
    };
    _: string; // Contenu HTML sous forme de chaîne
}
