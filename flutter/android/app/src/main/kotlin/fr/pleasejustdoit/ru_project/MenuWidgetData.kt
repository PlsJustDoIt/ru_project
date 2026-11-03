package fr.pleasejustdoit.ru_project

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Données du widget « Menu du RU ».
 *
 * Source : les SharedPreferences de home_widget, remplies par l'app Flutter
 * (`lib/services/menu_home_widget.dart`) puis rafraîchies ici directement
 * depuis l'API (`GET /ru/menus?restaurantId=…`, endpoint public).
 * Toutes les valeurs sont stockées en String (des deux côtés).
 */
object MenuWidgetData {
    private const val TAG = "MenuWidget"

    // Clés partagées avec menu_home_widget.dart — à garder synchronisées.
    const val KEY_API_URL = "menu_api_url"
    const val KEY_RESTAURANT_ID = "menu_restaurant_id"
    const val KEY_RESTAURANT_NAME = "menu_restaurant_name"
    const val KEY_MENUS_JSON = "menu_json"
    const val KEY_STATUS = "menu_status" // "ok" | "none" (RU sans menu publié)
    const val KEY_FETCHED_AT = "menu_fetched_at" // epoch ms

    // Clés propres au widget : jour affiché choisi avec les flèches.
    private const val KEY_SELECTED_DATE = "menu_widget_selected_date"
    private const val KEY_SELECTED_ON = "menu_widget_selected_on"

    /** Au-delà, le cache est jugé périmé et le widget recharge le menu. */
    private const val MAX_CACHE_AGE_MS = 3L * 60 * 60 * 1000

    /** Après cette heure, le service du midi est passé : on montre demain. */
    private const val LUNCH_OVER_HOUR = 14

    private const val NOT_COMMUNICATED = "menu non communiqué"

    /** Ordre d'affichage des catégories du flux CROUS (les autres suivent). */
    private val CATEGORY_ORDER = listOf(
        "Entrées",
        "Cuisine traditionnelle",
        "Menu végétalien",
        "Pizza",
        "Cuisine italienne",
        "Grill",
    )

    data class Row(val category: String, val dishes: String)

    data class Day(val date: String, val closedMessage: String?, val rows: List<Row>)

    data class State(
        val restaurantId: String?,
        val restaurantName: String?,
        /** Le RU ne publie aucun menu (cafét', foodtruck...). */
        val noMenuPublished: Boolean,
        /** Jours d'aujourd'hui et après, dans l'ordre. */
        val days: List<Day>,
        /** Index du jour affiché dans [days], -1 si aucun. */
        val selectedIndex: Int,
        val fetchedAt: Long,
    ) {
        val selectedDay: Day? get() = days.getOrNull(selectedIndex)
        val hasPrev: Boolean get() = selectedIndex > 0
        val hasNext: Boolean get() = selectedIndex in 0 until days.size - 1
    }

    fun prefs(context: Context): SharedPreferences = HomeWidgetPlugin.getData(context)

    private fun isoDay(cal: Calendar): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.time)

    fun load(prefs: SharedPreferences, now: Calendar = Calendar.getInstance()): State {
        val today = isoDay(now)
        val days = parseDays(prefs.getString(KEY_MENUS_JSON, null)).filter { it.date >= today }

        val selectedIndex = when {
            days.isEmpty() -> -1
            else -> {
                // Choix manuel (flèches) valable seulement le jour même
                val manual = prefs.getString(KEY_SELECTED_DATE, null)
                    ?.takeIf { prefs.getString(KEY_SELECTED_ON, null) == today }
                val manualIndex = days.indexOfFirst { it.date == manual }
                if (manualIndex >= 0) manualIndex else defaultIndex(days, now)
            }
        }

        return State(
            restaurantId = prefs.getString(KEY_RESTAURANT_ID, null)?.takeIf { it.isNotBlank() },
            restaurantName = prefs.getString(KEY_RESTAURANT_NAME, null)?.takeIf { it.isNotBlank() },
            noMenuPublished = prefs.getString(KEY_STATUS, null) == "none",
            days = days,
            selectedIndex = selectedIndex,
            fetchedAt = prefs.getString(KEY_FETCHED_AT, null)?.toLongOrNull() ?: 0L,
        )
    }

    /** Aujourd'hui, ou demain une fois le service du midi terminé. */
    private fun defaultIndex(days: List<Day>, now: Calendar): Int {
        val target = (now.clone() as Calendar).apply {
            if (get(Calendar.HOUR_OF_DAY) >= LUNCH_OVER_HOUR) add(Calendar.DAY_OF_YEAR, 1)
        }
        val targetDay = isoDay(target)
        val index = days.indexOfFirst { it.date >= targetDay }
        // Plus rien après la cible (ex. vendredi soir) : dernier jour connu
        return if (index >= 0) index else days.size - 1
    }

    /** Flèches précédent / suivant : mémorise le jour choisi pour aujourd'hui. */
    fun shiftDay(prefs: SharedPreferences, delta: Int) {
        val now = Calendar.getInstance()
        val state = load(prefs, now)
        if (state.selectedIndex < 0) return
        val target = state.days.getOrNull(state.selectedIndex + delta) ?: return
        prefs.edit()
            .putString(KEY_SELECTED_DATE, target.date)
            .putString(KEY_SELECTED_ON, isoDay(now))
            .apply()
    }

    fun needsRefresh(state: State, nowMs: Long = System.currentTimeMillis()): Boolean {
        if (state.restaurantId == null) return false
        if (nowMs - state.fetchedAt > MAX_CACHE_AGE_MS) return true
        // Cache récent mais plus aucun jour à venir (RU sans menu exclu)
        return state.days.isEmpty() && !state.noMenuPublished
    }

    /**
     * Recharge le menu depuis l'API (appel bloquant : hors thread principal).
     * Retourne true si les données ont changé.
     */
    fun fetch(context: Context): Boolean {
        val prefs = prefs(context)
        val apiUrl = prefs.getString(KEY_API_URL, null)?.trimEnd('/') ?: return false
        val restaurantId = prefs.getString(KEY_RESTAURANT_ID, null)
            ?.takeIf { it.isNotBlank() } ?: return false

        var connection: HttpURLConnection? = null
        try {
            val url = URI("$apiUrl/ru/menus?restaurantId=" + URLEncoder.encode(restaurantId, "UTF-8")).toURL()
            connection = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 5_000
                readTimeout = 8_000
                setRequestProperty("Accept", "application/json")
            }
            val code = connection.responseCode
            val (status, menusJson) = when (code) {
                200 -> {
                    val body = connection.inputStream.bufferedReader().use { it.readText() }
                    "ok" to JSONObject(body).getJSONArray("menus").toString()
                }
                404 -> "none" to "[]"
                else -> {
                    Log.w(TAG, "GET menus: HTTP $code")
                    return false
                }
            }
            // L'utilisateur a pu changer de RU dans l'app pendant la requête
            if (prefs.getString(KEY_RESTAURANT_ID, null) != restaurantId) return false
            prefs.edit()
                .putString(KEY_STATUS, status)
                .putString(KEY_MENUS_JSON, menusJson)
                .putString(KEY_FETCHED_AT, System.currentTimeMillis().toString())
                .apply()
            return true
        } catch (e: Exception) {
            Log.w(TAG, "GET menus impossible: ${e.message}")
            return false
        } finally {
            connection?.disconnect()
        }
    }

    /**
     * Parse le format brut de `GET /ru/menus` :
     * `[{date, fermeture}]` ou `[{date, "<catégorie>": String | [String]}]`.
     */
    private fun parseDays(json: String?): List<Day> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).mapNotNull { i ->
                val obj = array.optJSONObject(i) ?: return@mapNotNull null
                val date = obj.optString("date").take(10)
                if (date.length != 10) return@mapNotNull null
                if (obj.has("fermeture")) {
                    Day(date, obj.optString("fermeture"), emptyList())
                } else {
                    Day(date, null, parseRows(obj))
                }
            }.sortedBy { it.date }
        } catch (e: Exception) {
            Log.w(TAG, "menu_json illisible: ${e.message}")
            emptyList()
        }
    }

    private fun parseRows(obj: JSONObject): List<Row> {
        val keys = obj.keys().asSequence().filter { it != "date" }.toList()
        val ordered = CATEGORY_ORDER.filter { it in keys } + keys.filter { it !in CATEGORY_ORDER }
        return ordered.mapNotNull { category ->
            val dishes = when (val value = obj.opt(category)) {
                is JSONArray -> (0 until value.length()).map { value.optString(it) }
                is String -> listOf(value)
                else -> emptyList()
            }.map { it.trim() }
                .filter { it.isNotEmpty() && !it.equals(NOT_COMMUNICATED, ignoreCase = true) }
            if (dishes.isEmpty()) null else Row(category, dishes.joinToString("\n"))
        }
    }
}
