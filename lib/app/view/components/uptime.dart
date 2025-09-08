import 'dart:async';
import 'package:flutter/material.dart';

class Uptime extends StatefulWidget {
  final Function callBack;

  const Uptime({super.key, required this.callBack});

  @override
  _UptimeState createState() => _UptimeState();
}

class _UptimeState extends State<Uptime> {
  late Timer _timer;
  int _timeElapsed = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeElapsed++;
      });
    });
  }

  String _formatTime(int time) {
    int hours = time ~/ 3600;
    int minutes = (time % 3600) ~/ 60;
    int seconds = time % 60;
    String formattedTime = '';
    if (hours > 0) {
      formattedTime += '${hours.toString().padLeft(2, '0')}:';
    }
    formattedTime += '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return formattedTime;
  }

  int getElapsedTime() {
    return _timeElapsed;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatTime(_timeElapsed),
      style: const TextStyle(
          color: Colors.red, fontFamily: "semibold"
      ),
    );
  }
}
