import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:my_app/service/firestore_service.dart';
import 'package:my_app/service/gemini_service.dart';

class BubbleWidgetOverlay extends StatefulWidget {
  const BubbleWidgetOverlay({Key? key}) : super(key: key);

  @override
  State<BubbleWidgetOverlay> createState() => _BubbleWidgetOverlayState();
}

class _BubbleWidgetOverlayState extends State<BubbleWidgetOverlay> {
  bool isExpanded = false;
  bool isExplainMode = false;
  String _explanation = "";
  final TextEditingController _textController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final GeminiService _geminiService = GeminiService();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> toggleExpansion() async {
    setState(() {
      isExpanded = !isExpanded;
    });

    if (isExpanded) {
      await FlutterOverlayWindow.moveOverlay(OverlayPosition(0, 0));
      if(isExplainMode){
        FlutterOverlayWindow.resizeOverlay(370, 800, false);
      } else{
        await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
        await FlutterOverlayWindow.resizeOverlay(350, 350, true);
      }
    } else {
      await FlutterOverlayWindow.moveOverlay(OverlayPosition(180, -250));
      await FlutterOverlayWindow.resizeOverlay(60, 60, true);
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    }
  }

  void _sendVocabToFirebase() async {
    String text = _textController.text;
    if (text.isNotEmpty) {
      _firestoreService.addWordToVocab(word: text);
      _textController.clear();
    }
  }

  void _sendQuoteToFirebase() {
    String text = _textController.text;
    if (text.isNotEmpty) {
      _firestoreService.addToGoodStuff(content: text);
      _textController.clear();
    }
  }

  void _explainText() async {
    String text = _textController.text;
    String explanation = "";
    if (text.isNotEmpty) {
      explanation = await _geminiService.generateExplanation(text);
    }
    setState(() {
      isExplainMode = true;
      _explanation = explanation;
    });
    FlutterOverlayWindow.resizeOverlay(370, 800, false);
  }


  Widget _buildTextFieldWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: _textController,
        maxLines: null,
        decoration: InputDecoration(
          hintText: "Paste or type your text here...",
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildExplanationWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Explanation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isExplainMode = false;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              _explanation,
              style: TextStyle(
                fontSize: 13,
                color: Colors.purple[800],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: toggleExpansion,
        child: Container(
          decoration: BoxDecoration(
            gradient: isExpanded
                ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            )
                : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple, Colors.purple],
            ),
            borderRadius: BorderRadius.circular(isExpanded ? 16 : 30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
            border: isExpanded
                ? Border.all(color: Colors.grey[200]!, width: 1)
                : null,
          ),
          child: isExpanded ? _buildExpandedView() : _buildCollapsedView(),
        ),
      ),
    );
  }

  Widget _buildCollapsedView() {
    return Container(
      width: 60,
      height: 60,
      child: Center(
        child: Icon(
          Icons.save_alt_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.purple],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Quick Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          GestureDetector(
            onTap: _closeOverlay,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your text',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            flex: isExplainMode ? 5 : 1,
            child: Column(
              children: [
                _buildTextFieldWidget(),
                const SizedBox(height: 0),
                if (isExplainMode)
                  Expanded(child: _buildExplanationWidget()),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Options',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildActionButton(
                      'Vocabulary',
                      Icons.book_rounded,
                      Colors.blue,
                      _sendVocabToFirebase,
                    )),
                    SizedBox(width: 8),
                    Expanded(child: _buildActionButton(
                      'Good Stuff',
                      Icons.format_quote_rounded,
                      Colors.orange,
                      _sendQuoteToFirebase,
                    )),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildActionButton(
                      'Explain',
                      Icons.psychology_rounded,
                      Colors.purple,
                      _explainText,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}