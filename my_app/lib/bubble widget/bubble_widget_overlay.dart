import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:my_app/service/firestore_service.dart';

class BubbleWidgetOverlay extends StatefulWidget {
  const BubbleWidgetOverlay({Key? key}) : super(key: key);

  @override
  State<BubbleWidgetOverlay> createState() => _BubbleWidgetOverlayState();
}

class _BubbleWidgetOverlayState extends State<BubbleWidgetOverlay> {
  bool isExpanded = false;
  final TextEditingController _textController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {

    super.initState();
  }
  Future<void> _closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> toggleExpansion() async {
    setState(() {
      isExpanded = !isExpanded;
    });

    // Resize the overlay after state update
    if (isExpanded) {
      // true and false here to make it can movable or not
      await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
      await FlutterOverlayWindow.moveOverlay(OverlayPosition(0, 0));
      await FlutterOverlayWindow.resizeOverlay(400, 200, true);
    } else {
      await FlutterOverlayWindow.moveOverlay(OverlayPosition(180, -250));
      await FlutterOverlayWindow.resizeOverlay(50, 50, true);
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    }
  }

  void _sendVocabToFirebase() async{
    String text = _textController.text;
    if (text.isNotEmpty) {
      _firestoreService.addWordToVocab(word: text);
      _textController.clear();
    }
  }
  void _sendQuoteToFirebase() {}
  void _sendFactToFirebase() {}

  // overlay ui
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: toggleExpansion,
        child: Container(
          decoration: BoxDecoration(
            color: isExpanded ? Colors.blue[50] : Colors.blue,
            borderRadius: BorderRadius.circular(isExpanded ? 10 : 30),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: isExpanded
              ? Column(
                  children: [
                    Container(
                      height: 40,
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[500],
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Firebase Widget',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _closeOverlay();
                            },
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              'Clipboard text',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "Paste text here",
                                  border: OutlineInputBorder(),
                                  fillColor: Colors.white,
                                  filled: true,
                                ),
                                maxLines: null,
                                keyboardType: TextInputType.text,
                                autofocus: true, // triggers keyboard (might not work in overlay!)
                                controller: _textController,
                                focusNode: FocusNode(),
                              ),
                            ),


                            SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _sendVocabToFirebase,
                                    child: Text("Save Vocab"),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _sendQuoteToFirebase,
                                    child: Text("Save Quote"),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _sendFactToFirebase,
                                    child: Text("Save Fact"),
                                  ),
                                ],
                              ),
                            ),

                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(
                    Icons.save_as_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
        ),
      ),
    );
  }
}
