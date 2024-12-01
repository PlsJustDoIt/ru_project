# ginko.ts

/**
 * @api {get} /api/route Get Route Information
 * @apiName GetRoute
 * @apiGroup Route
 * 
 * @apiParam {String} nomExact Exact name of the route.
 * @apiParam {Object[]} listeTemps List of time information for each stop.
 * @apiParam {String} listeTemps.idArret ID of the stop.
 * @apiParam {Number} listeTemps.latitude Latitude of the stop.
 * @apiParam {Number} listeTemps.longitude Longitude of the stop.
 * @apiParam {String} listeTemps.idLigne ID of the line.
 * @apiParam {String} listeTemps.numLignePublic Public number of the line.
 * @apiParam {String} listeTemps.couleurFond Background color of the line.
 * @apiParam {String} listeTemps.couleurTexte Text color of the line.
 * @apiParam {Boolean} listeTemps.sensAller Direction of the route (true for forward).
 * @apiParam {String} listeTemps.destination Destination of the route.
 * @apiParam {String} listeTemps.precisionDestination Precision of the destination.
 * @apiParam {String} listeTemps.temps Time information.
 * @apiParam {String} listeTemps.tempsHTML HTML formatted time information.
 * @apiParam {Number} listeTemps.tempsEnSeconde Time in seconds.
 * @apiParam {Number} listeTemps.typeDeTemps Type of time.
 * @apiParam {Boolean} listeTemps.alternance Alternation flag.
 * @apiParam {String} listeTemps.tempsHTMLEnAlternance HTML formatted time information in alternation.
 * @apiParam {Boolean} listeTemps.fiable Reliability flag.
 * @apiParam {String} listeTemps.numVehicule Vehicle number.
 * @apiParam {Number} listeTemps.accessibiliteArret Accessibility of the stop.
 * @apiParam {Number} listeTemps.accessibiliteVehicule Accessibility of the vehicle.
 * @apiParam {Number} listeTemps.affluence Affluence level.
 * @apiParam {String} listeTemps.texteAffluence Affluence text.
 * @apiParam {String} listeTemps.aideDecisionAffluence Affluence decision aid.
 * @apiParam {Number} listeTemps.tauxDeCharge Load rate.
 * @apiParam {Number} listeTemps.idInfoTrafic Traffic information ID.
 * @apiParam {Number} listeTemps.modeTransport Mode of transport.
 * @apiParam {Number} latitude Latitude of the route.
 * @apiParam {Number} longitude Longitude of the route.
 * 
 * @apiSuccess {String} nomExact Exact name of the route.
 * @apiSuccess {Object[]} listeTemps List of time information for each stop.
 * @apiSuccess {String} listeTemps.idArret ID of the stop.
 * @apiSuccess {Number} listeTemps.latitude Latitude of the stop.
 * @apiSuccess {Number} listeTemps.longitude Longitude of the stop.
 * @apiSuccess {String} listeTemps.idLigne ID of the line.
 * @apiSuccess {String} listeTemps.numLignePublic Public number of the line.
 * @apiSuccess {String} listeTemps.couleurFond Background color of the line.
 * @apiSuccess {String} listeTemps.couleurTexte Text color of the line.
 * @apiSuccess {Boolean} listeTemps.sensAller Direction of the route (true for forward).
 * @apiSuccess {String} listeTemps.destination Destination of the route.
 * @apiSuccess {String} listeTemps.precisionDestination Precision of the destination.
 * @apiSuccess {String} listeTemps.temps Time information.
 * @apiSuccess {String} listeTemps.tempsHTML HTML formatted time information.
 * @apiSuccess {Number} listeTemps.tempsEnSeconde Time in seconds.
 * @apiSuccess {Number} listeTemps.typeDeTemps Type of time.
 * @apiSuccess {Boolean} listeTemps.alternance Alternation flag.
 * @apiSuccess {String} listeTemps.tempsHTMLEnAlternance HTML formatted time information in alternation.
 * @apiSuccess {Boolean} listeTemps.fiable Reliability flag.
 * @apiSuccess {String} listeTemps.numVehicule Vehicle number.
 * @apiSuccess {Number} listeTemps.accessibiliteArret Accessibility of the stop.
 * @apiSuccess {Number} listeTemps.accessibiliteVehicule Accessibility of the vehicle.
 * @apiSuccess {Number} listeTemps.affluence Affluence level.
 * @apiSuccess {String} listeTemps.texteAffluence Affluence text.
 * @apiSuccess {String} listeTemps.aideDecisionAffluence Affluence decision aid.
 * @apiSuccess {Number} listeTemps.tauxDeCharge Load rate.
 * @apiSuccess {Number} listeTemps.idInfoTrafic Traffic information ID.
 * @apiSuccess {Number} listeTemps.modeTransport Mode of transport.
 * @apiSuccess {Number} latitude Latitude of the route.
 * @apiSuccess {Number} longitude Longitude of the route.
 */
{
  "nomExact": "string",
  "listeTemps": [
    {
      "idArret": "string",
      "latitude": 0,
      "longitude": 0,
      "idLigne": "string",
      "numLignePublic": "string",
      "couleurFond": "string",
      "couleurTexte": "string",
      "sensAller": true,
      "destination": "string",
      "precisionDestination": "string",
      "temps": "string",
      "tempsHTML": "string",
      "tempsEnSeconde": 0,
      "typeDeTemps": 0,
      "alternance": true,
      "tempsHTMLEnAlternance": "string",
      "fiable": true,
      "numVehicule": "string",
      "accessibiliteArret": 0,
      "accessibiliteVehicule": 0,
      "affluence": -1,
      "texteAffluence": "string",
      "aideDecisionAffluence": "string",
      "tauxDeCharge": 0,
      "idInfoTrafic": 0,
      "modeTransport": 0
    }
  ],
  "latitude": 0,
  "longitude": 0
}