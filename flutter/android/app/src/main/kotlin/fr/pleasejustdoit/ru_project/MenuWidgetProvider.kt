package fr.pleasejustdoit.ru_project

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Widget d'écran d'accueil « Menu du RU » : affiche, sous forme de tableau
 * catégorie | plats, le menu du RU sélectionné dans l'app.
 *
 * - redessiné quand l'app pousse de nouvelles données (HomeWidget.updateWidget) ;
 * - se rafraîchit seul via l'API quand son cache est périmé (cf. MenuWidgetData) ;
 * - flèches pour parcourir les jours, bouton actualiser, tap = ouvrir l'app.
 */
class MenuWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        render(context, appWidgetManager, appWidgetIds, widgetData, refreshing = false)
        if (MenuWidgetData.needsRefresh(MenuWidgetData.load(widgetData))) {
            refreshAsync(context, showProgress = false)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_PREV, ACTION_NEXT -> {
                val delta = if (intent.action == ACTION_NEXT) 1 else -1
                MenuWidgetData.shiftDay(MenuWidgetData.prefs(context), delta)
                renderAll(context, refreshing = false)
            }
            ACTION_REFRESH -> refreshAsync(context, showProgress = true)
            else -> super.onReceive(context, intent)
        }
    }

    /** Recharge le menu hors thread principal, puis redessine tous les widgets. */
    private fun refreshAsync(context: Context, showProgress: Boolean) {
        if (!refreshing.compareAndSet(false, true)) return
        val appContext = context.applicationContext
        if (showProgress) renderAll(appContext, refreshing = true)
        val pendingResult = goAsync()
        Thread {
            try {
                MenuWidgetData.fetch(appContext)
                renderAll(appContext, refreshing = false)
            } finally {
                refreshing.set(false)
                pendingResult.finish()
            }
        }.start()
    }

    companion object {
        private const val ACTION_PREV = "fr.pleasejustdoit.ru_project.menu_widget.PREV"
        private const val ACTION_NEXT = "fr.pleasejustdoit.ru_project.menu_widget.NEXT"
        private const val ACTION_REFRESH = "fr.pleasejustdoit.ru_project.menu_widget.REFRESH"

        private val refreshing = AtomicBoolean(false)

        fun renderAll(context: Context, refreshing: Boolean) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, MenuWidgetProvider::class.java))
            if (ids.isNotEmpty()) {
                render(context, manager, ids, MenuWidgetData.prefs(context), refreshing)
            }
        }

        private fun render(
            context: Context,
            manager: AppWidgetManager,
            ids: IntArray,
            prefs: SharedPreferences,
            refreshing: Boolean,
        ) {
            val state = MenuWidgetData.load(prefs)
            for (id in ids) {
                manager.updateAppWidget(id, buildViews(context, id, state, refreshing))
            }
            // Le contenu de la liste est produit par MenuWidgetService
            // (API dépréciée en 35 au profit de RemoteCollectionItems, API 31+)
            @Suppress("DEPRECATION")
            manager.notifyAppWidgetViewDataChanged(ids, R.id.menu_widget_list)
        }

        private fun buildViews(
            context: Context,
            widgetId: Int,
            state: MenuWidgetData.State,
            refreshing: Boolean,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.menu_widget)
            val day = state.selectedDay

            views.setTextViewText(
                R.id.menu_widget_title,
                state.restaurantName ?: context.getString(R.string.menu_widget_default_title),
            )
            views.setTextViewText(
                R.id.menu_widget_day,
                when {
                    refreshing -> context.getString(R.string.menu_widget_refreshing)
                    day != null -> dayLabel(context, day.date)
                    else -> ""
                },
            )
            views.setViewVisibility(R.id.menu_widget_prev, if (state.hasPrev) View.VISIBLE else View.INVISIBLE)
            views.setViewVisibility(R.id.menu_widget_next, if (state.hasNext) View.VISIBLE else View.INVISIBLE)
            views.setViewVisibility(
                R.id.menu_widget_refresh,
                if (state.restaurantId != null) View.VISIBLE else View.GONE,
            )

            // Tableau des plats : adapter distant, intent unique par widget
            val serviceIntent = Intent(context, MenuWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            @Suppress("DEPRECATION")
            views.setRemoteAdapter(R.id.menu_widget_list, serviceIntent)
            views.setEmptyView(R.id.menu_widget_list, R.id.menu_widget_empty)
            views.setTextViewText(R.id.menu_widget_empty, emptyMessage(context, state))

            // Interactions
            val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.menu_widget_header, openApp)
            views.setOnClickPendingIntent(R.id.menu_widget_empty, openApp)
            views.setPendingIntentTemplate(R.id.menu_widget_list, openAppTemplate(context))
            views.setOnClickPendingIntent(R.id.menu_widget_refresh, broadcast(context, ACTION_REFRESH, 1))
            views.setOnClickPendingIntent(R.id.menu_widget_prev, broadcast(context, ACTION_PREV, 2))
            views.setOnClickPendingIntent(R.id.menu_widget_next, broadcast(context, ACTION_NEXT, 3))
            return views
        }

        /** Texte affiché quand le tableau est vide (aucune ligne pour le jour). */
        private fun emptyMessage(context: Context, state: MenuWidgetData.State): String {
            val day = state.selectedDay
            return when {
                state.restaurantId == null -> context.getString(R.string.menu_widget_no_restaurant)
                state.noMenuPublished -> context.getString(R.string.menu_widget_no_menu_published)
                day == null && state.fetchedAt == 0L -> context.getString(R.string.menu_widget_loading)
                day == null -> context.getString(R.string.menu_widget_no_upcoming)
                day.closedMessage != null -> {
                    val closed = context.getString(R.string.menu_widget_closed)
                    if (day.closedMessage.isBlank()) closed else "$closed\n${day.closedMessage}"
                }
                else -> context.getString(R.string.menu_widget_not_communicated)
            }
        }

        /** « Aujourd'hui · mardi 3 novembre », « Demain · … » ou « Jeudi 5 novembre ». */
        private fun dayLabel(context: Context, isoDate: String): String {
            val parsed = try {
                SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(isoDate)
            } catch (e: Exception) {
                null
            } ?: return isoDate
            val formatted = SimpleDateFormat("EEEE d MMMM", Locale.FRENCH).format(parsed)
                .replaceFirstChar { it.titlecase(Locale.FRENCH) }

            val iso = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val now = Calendar.getInstance()
            val today = iso.format(now.time)
            now.add(Calendar.DAY_OF_YEAR, 1)
            val tomorrow = iso.format(now.time)
            return when (isoDate) {
                today -> context.getString(R.string.menu_widget_today) + " · " + formatted
                tomorrow -> context.getString(R.string.menu_widget_tomorrow) + " · " + formatted
                else -> formatted
            }
        }

        private fun immutableFlag(): Int =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        private fun broadcast(context: Context, action: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, MenuWidgetProvider::class.java).setAction(action)
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
            )
        }

        /** Modèle pour les lignes de la liste (doit être mutable pour le fill-in). */
        private fun openAppTemplate(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java)
                .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
            val mutable =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            return PendingIntent.getActivity(
                context,
                10,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or mutable,
            )
        }
    }
}
