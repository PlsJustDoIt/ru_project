import 'package:flutter/material.dart';

class StateWidget extends StatefulWidget {
  const StateWidget({super.key});

  @override
  State<StateWidget> createState() => _StateWidgetState();
}

class _StateWidgetState extends State<StateWidget> {
  bool _isStateTwo = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isStateTwo ? "state 2" : "state 1",
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(width: 20), // Adding some space between text and switch
        Switch(
          value: _isStateTwo,
          onChanged: (bool value) {
            setState(() {
              _isStateTwo = value;
            });
          },
          
        ),
      ],
    );
  }
}