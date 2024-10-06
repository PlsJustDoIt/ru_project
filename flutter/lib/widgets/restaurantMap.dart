import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class restaurantMapWidget extends StatefulWidget {
  const restaurantMapWidget({Key? key}) : super(key: key);
  
  @override
  State<restaurantMapWidget> createState() => _mapState();


}

class _mapState extends State<restaurantMapWidget> {
  @override
  Widget build(BuildContext context) {
    // draw a rectangle on the map
    return Container(
      child: Column(
        children: [
          Text('Map'),
          const Text(
            'Bienvenue !',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          )
          .animate()
          .tint(color: Colors.green)
          .slide(duration: 500.ms, curve: Curves.easeIn)
          .fadeIn(duration: 500.ms, begin: 0)
          .animate(onPlay: (controller) => controller.repeat())
          .fadeIn(duration: 500.ms, begin: 0)
          .shake(delay: 1.seconds)
          .fadeOut(duration: 500.ms, delay: 2.seconds),
          ClipRRect(
            borderRadius: BorderRadius.circular(30.0),
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(
                maxWidth: 300,
                maxHeight: 100,
              ),
              color: Colors.green,
              child: const Text('ClipRRect', style: TextStyle(color: Colors.white)),
            ),
          ),
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
