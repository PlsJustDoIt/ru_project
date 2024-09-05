const express = require('express');
const auth = require('../middleware/auth');
const User = require('../models/user');
const router = express.Router();
const NodeCache = require( "node-cache" );
const axios = require('axios');
const xml2js = require('xml2js');

const ru_lumiere_id = 'r135';
const api_url = 'http://webservices-v2.crous-mobile.fr:8080/feed/bfc/externe/menu.xml';

const cache = new NodeCache({ stdTTL: 3600 });

// Fonction pour récupérer les menus de l'API externe
async function fetchMenusFromExternalAPI() {
    try {
      // L'URL de l'API qui retourne le document XML des menus
      const response = await axios.get(api_url);
      const xmlData = response.data;
  
      // Conversion du XML en objet JS
      const parser = new xml2js.Parser({ explicitArray: false });
      const result = await parser.parseStringPromise(xmlData);

     // console.log(result);
  
        const restaurants = result.root.resto;
      const restoR135 = restaurants.find(resto => resto.$.id === 'r135');
      const menusR135 = restoR135.menu;
    console.log(menusR135);
      return menusR135;
    } catch (error) {
      console.error('Erreur lors de la récupération des menus:', error);
      throw error;
    }
  }

  router.get('/menus', async (req, res) => {
    try {
      // On vérifie si les menus sont en cache
      const cachedMenus = cache.get('menus');
      if (cachedMenus) {
        console.log('Les menus sont en cache');
        return res.json(cachedMenus);
      }
  
      // Si les menus ne sont pas en cache, on les récupère de l'API externe
      const menus = await fetchMenusFromExternalAPI();
  
      // On met les menus en cache pour 1 heure
      cache.set('menus', menus);
  
      res.json(menus);
    } catch (error) {
      console.error('Erreur lors de la récupération des menus:', error);
      res.status(500).send('Erreur lors de la récupération des menus');
    }
  }
);

module.exports = router;