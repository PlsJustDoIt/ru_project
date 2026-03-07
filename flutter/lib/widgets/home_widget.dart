import 'package:home_widget/home_widget.dart';
import 'package:ru_project/models/menu.dart';

Future<void> updateHomeWidgetWithMenu(Menu menu) async {
  String content;

  if (menu.fermeture != null) {
    content = "Fermé le ${menu.date} : ${menu.fermeture}";
  } else if (menu.plats != null) {
    final plats = menu.plats!;
    content = "${menu.date}\n"
        "Entrées: ${plats["Entrées"]}\n"
        "Pizza: ${plats["Pizza"]}\n"
        "Végétalien: ${plats["Menu végétalien"]}";
  } else {
    content = "Menu non disponible pour le ${menu.date}";
  }

  await HomeWidget.saveWidgetData<String>('menu', content);
  await HomeWidget.updateWidget(
    name: 'MenuWidgetProvider',
    androidName: 'MenuWidgetProvider',
  );
}
