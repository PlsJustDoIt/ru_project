import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/home_page.dart';
import 'package:ru_project/login_page.dart';
import 'package:ru_project/menu.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/widgets/welcomeWidget.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() {
  dotenv.load(fileName: ".env");
  runApp(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => UserProvider()),
    ],
    child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  

  @override 
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      home:LoginPage(),
    );
    // return MaterialApp(
    //   home: Scaffold(
    //     appBar: AppBar(
    //       title: const Text('Projet ru de léo'),
    //       backgroundColor: const Color.fromARGB(209, 66, 206, 62),
    //     ),
    //     body: const UserStateWidget(),
    //   ),
    //   title: 'Projet ru',
    //   theme: ThemeData(
    //     colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green),
    //     useMaterial3: true,
    //   ),
    // );
  }
}

class UserStateWidget extends StatefulWidget {
  const UserStateWidget({super.key});

  @override
  _UserStateWidgetState createState() => _UserStateWidgetState();
}

class _UserStateWidgetState extends State<UserStateWidget> {
  String _currentState = "Inactif"; // État par défaut

  void _changeState(String newState) {
    setState(() {
      _currentState = newState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Text(
          //   'État actuel : $_currentState',
          //   style: const TextStyle(
          //     fontSize: 24,
          //     color: Colors.green,
          //   ),
          // ),
          // const SizedBox(height: 20), // Espacement
          //   Column(
          //   children: [
          //     Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: ElevatedButton(
          //       onPressed: () => _changeState("Inactif"),
          //       child: const Text('Inactif'),
          //     ),
          //     ),
          //     Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: ElevatedButton(
          //       onPressed: () => _changeState("Sur le point de manger"),
          //       child: const Text('Sur le point de manger'),
          //     ),
          //     ),
          //     Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: ElevatedButton(
          //       onPressed: () => _changeState("A fini de manger"),
          //       child: const Text('A fini de manger'),
          //     ),
          //     ),
          //   ],
          //   ),
        
          const Text(
          'Bienvenue !',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ).animate().tint(color: Colors.green).slide(duration: 500.ms,curve: Curves.easeIn).fadeIn(duration: 500.ms,begin: 0).animate(onPlay: (controller) => controller.repeat()).fadeIn(duration: 500.ms,begin: 0).shake(delay: 1.seconds).fadeOut(duration: 500.ms,delay: 2.seconds),
          Image.asset(
            "assets/images/jm.jpg",
            width: 200,
            height: 200,
          ),
        ],
      ),
    );
  }
}

class TabBarWidget extends StatelessWidget {
  const TabBarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Projet ru de léo'),
          backgroundColor: const Color.fromARGB(209, 66, 206, 62),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.login), text: 'Default'),
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu ru'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LoginPage(),
            MenuWidget(),
          ],
        ),
      ),
    );
  }
}
