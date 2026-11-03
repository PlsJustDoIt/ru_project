package fr.pleasejustdoit.ru_project

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/**
 * Fournit les lignes du tableau (catégorie | plats) du jour affiché par le
 * widget « Menu du RU ». Relit les données à chaque
 * notifyAppWidgetViewDataChanged (cf. MenuWidgetProvider.render).
 */
class MenuWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        MenuRowsFactory(applicationContext)
}

private class MenuRowsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var rows: List<MenuWidgetData.Row> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        rows = MenuWidgetData.load(MenuWidgetData.prefs(context)).selectedDay?.rows ?: emptyList()
    }

    override fun onDestroy() {
        rows = emptyList()
    }

    override fun getCount(): Int = rows.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.menu_widget_row)
        val row = rows.getOrNull(position) ?: return views
        views.setTextViewText(R.id.menu_widget_row_category, row.category)
        views.setTextViewText(R.id.menu_widget_row_dishes, row.dishes)
        // Lignes zébrées pour l'effet tableau
        views.setInt(
            R.id.menu_widget_row,
            "setBackgroundResource",
            if (position % 2 == 1) R.color.menu_widget_row_alt else 0,
        )
        // Tap sur une ligne = ouvrir l'app (modèle défini par le provider)
        views.setOnClickFillInIntent(R.id.menu_widget_row, Intent())
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false
}
