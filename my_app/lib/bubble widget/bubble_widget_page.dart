import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class BubbleWidget extends StatelessWidget {
  const BubbleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bubble Widget"),
      ),
      body: const BubbleWidgetPage(),
    );
  }
}

class BubbleWidgetPage extends StatefulWidget  {
  const BubbleWidgetPage({super.key});


  @override
  State<BubbleWidgetPage> createState() => _BubbleWidgetPageState();
}

class _BubbleWidgetPageState extends State<BubbleWidgetPage>{
  bool isOverlayActive = false;

  @override
  void initState() {
    super.initState();
    checkOverlayStatus();
  }

  Future<void> checkOverlayStatus() async {
    final status = await FlutterOverlayWindow.isActive();
    setState(() {
      isOverlayActive = status;
    });
  }

  Future<void> requestPermission() async {
    final isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      final result = await FlutterOverlayWindow.requestPermission();
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission granted! You can now show the chat head.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission denied. Go to Settings > Apps > Special access > Display over other apps')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission already granted!')),
      );
    }
  }

  Future<void> _showBubbleOverlay() async {
    final isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please grant permission first')),
      );
      return;
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      startPosition: OverlayPosition(180, -350),
      height: 150,
      width: 150,
    );

    setState(() {
      isOverlayActive = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Chat head is now active! Go to another app to see it.')),
    );
  }

  Future<void> _closeBubbleOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
    setState(() {
      isOverlayActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble,
              size: 80,
              color: Colors.blue,
            ),
            SizedBox(height: 20),
            Text(
              'Bubble Widget',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Create a bubble to manually copy paste and  send data to firebase',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 40),

            // Permission Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: requestPermission,
                icon: Icon(Icons.security),
                label: Text("Request Permission"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),

            SizedBox(height: 15),

            // Show Chat Head Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isOverlayActive ? null : _showBubbleOverlay,
                icon: Icon(Icons.chat),
                label: Text(isOverlayActive ? "Chat Head Active" : "Show Chat Head"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: isOverlayActive ? Colors.grey : Colors.blue,
                ),
              ),
            ),

            SizedBox(height: 15),

            // Close Chat Head Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isOverlayActive ? _closeBubbleOverlay : null,
                icon: Icon(Icons.close),
                label: Text("Close Chat Head"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: isOverlayActive ? Colors.red : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}