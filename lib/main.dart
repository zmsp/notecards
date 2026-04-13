import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

List<CameraDescription> globalCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    globalCameras = await availableCameras();
  } catch (e) {
    debugPrint("Failed to load cameras: $e");
  }
  runApp(const PromptlyApp());
}

class TeleprompterSettings {
  double fontSize;
  int scrollSpeed;
  Color textColor;
  Color backgroundColor;
  bool showFocusLine;
  bool showCameraPreview;
  bool recordVideo;

  TeleprompterSettings({
    this.fontSize = 48.0,
    this.scrollSpeed = 4,
    this.textColor = Colors.black,
    this.backgroundColor = const Color(0xFFF9F9F9),
    this.showFocusLine = true,
    this.showCameraPreview = false,
    this.recordVideo = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'scrollSpeed': scrollSpeed,
      'textColor': textColor.value,
      'backgroundColor': backgroundColor.value,
      'showFocusLine': showFocusLine,
      'showCameraPreview': showCameraPreview,
      'recordVideo': recordVideo,
    };
  }

  factory TeleprompterSettings.fromMap(Map<String, dynamic> map) {
    return TeleprompterSettings(
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 48.0,
      scrollSpeed: map['scrollSpeed'] ?? 4,
      textColor: Color(map['textColor'] ?? Colors.black.value),
      backgroundColor: Color(map['backgroundColor'] ?? const Color(0xFFF9F9F9).value),
      showFocusLine: map['showFocusLine'] ?? true,
      showCameraPreview: map['showCameraPreview'] ?? false,
      recordVideo: map['recordVideo'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory TeleprompterSettings.fromJson(String source) =>
      TeleprompterSettings.fromMap(json.decode(source));
}

class PromptlyApp extends StatefulWidget {
  const PromptlyApp({Key? key}) : super(key: key);

  @override
  State<PromptlyApp> createState() => _PromptlyAppState();
}

class _PromptlyAppState extends State<PromptlyApp> {
  TeleprompterSettings settings = TeleprompterSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('teleprompter_settings');
    if (jsonString != null) {
      try {
        setState(() {
          settings = TeleprompterSettings.fromJson(jsonString);
          _isLoading = false;
        });
      } catch (e) {
        debugPrint("Error loading settings: $e");
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings(TeleprompterSettings newSettings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teleprompter_settings', newSettings.toJson());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator(color: Colors.black)),
        ),
      );
    }

    return MaterialApp(
      title: 'Promptly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.black87,
          onSecondary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: EditorScreen(
        settings: settings,
        onSettingsChanged: (s) {
          setState(() {
            settings = s;
          });
          _saveSettings(s);
        },
      ),
    );
  }
}

class EditorScreen extends StatefulWidget {
  final TeleprompterSettings settings;
  final ValueChanged<TeleprompterSettings> onSettingsChanged;

  const EditorScreen({
    Key? key,
    required this.settings,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPersistedText();
    _textController.addListener(_savePersistedText);
  }

  Future<void> _loadPersistedText() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('editor_text');
    if (text != null) {
      _textController.text = text;
    }
  }

  Future<void> _savePersistedText() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('editor_text', _textController.text);
  }

  void _openSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SettingsModal(
          initialSettings: widget.settings,
          onApply: (newSettings) {
            widget.onSettingsChanged(newSettings);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _startTeleprompter() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter some text to prompt.")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrompterScreen(
          text: _textController.text,
          initialSettings: widget.settings,
          onSettingsChanged: widget.onSettingsChanged,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.removeListener(_savePersistedText);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promptly Editor', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            icon: const FaIcon(FontAwesomeIcons.gear, color: Colors.black87, size: 18),
            label: const Text("More Options", style: TextStyle(color: Colors.black87)),
            onPressed: _openSettingsDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Paste your speech or lyrics below:",
              style: TextStyle(fontSize: 18, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontSize: 20, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: "Start typing or paste here...\nUse [Chorus: Name] for colored duet parts!",
                    hintStyle: TextStyle(color: Colors.black26),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openSettingsDialog,
                  icon: const Icon(Icons.settings, size: 24, color: Colors.black87),
                  label: const Text("More Options", style: TextStyle(fontSize: 16, color: Colors.black87)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.black12),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _startTeleprompter,
                  icon: const Icon(Icons.play_arrow, size: 28, color: Colors.white),
                  label: const Text("Start Prompting", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsModal extends StatefulWidget {
  final TeleprompterSettings initialSettings;
  final ValueChanged<TeleprompterSettings> onApply;

  const SettingsModal({
    Key? key,
    required this.initialSettings,
    required this.onApply,
  }) : super(key: key);

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  late double _fontSize;
  late int _scrollSpeed;
  late bool _showFocusLine;
  late bool _showCameraPreview;
  late bool _recordVideo;
  
  final List<Map<String, dynamic>> _schemes = [
    {'name': 'White on Black', 'text': Colors.white, 'bg': Colors.black},
    {'name': 'Yellow on Black', 'text': Colors.yellowAccent, 'bg': Colors.black},
    {'name': 'Black on White', 'text': Colors.black, 'bg': Colors.white},
  ];

  late Color _textColor;
  late Color _backgroundColor;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.initialSettings.fontSize;
    _scrollSpeed = widget.initialSettings.scrollSpeed;
    _showFocusLine = widget.initialSettings.showFocusLine;
    _showCameraPreview = widget.initialSettings.showCameraPreview;
    _recordVideo = widget.initialSettings.recordVideo;
    _textColor = widget.initialSettings.textColor;
    _backgroundColor = widget.initialSettings.backgroundColor;
  }

  void _apply() {
    widget.onApply(TeleprompterSettings(
      fontSize: _fontSize,
      scrollSpeed: _scrollSpeed,
      textColor: _textColor,
      backgroundColor: _backgroundColor,
      showFocusLine: _showFocusLine,
      showCameraPreview: _showCameraPreview,
      recordVideo: _recordVideo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "More Options",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Font Size
            Row(
              children: [
                const Icon(Icons.format_size),
                const SizedBox(width: 16),
                const Text("Font Size"),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 20,
                    max: 120,
                    divisions: 100,
                    label: _fontSize.round().toString(),
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
              ],
            ),

            // Speed Baseline
            Row(
              children: [
                const Icon(Icons.speed),
                const SizedBox(width: 16),
                const Text("Default Speed"),
                Expanded(
                  child: Slider(
                    value: _scrollSpeed.toDouble(),
                    min: 1,
                    max: 40,
                    divisions: 39,
                    label: _scrollSpeed.toString(),
                    onChanged: (v) => setState(() => _scrollSpeed = v.toInt()),
                  ),
                ),
              ],
            ),

            // Toggles
            SwitchListTile(
              title: const Text("Show Reading Focus Line"),
              value: _showFocusLine,
              onChanged: (v) => setState(() => _showFocusLine = v),
              secondary: const Icon(Icons.center_focus_strong),
            ),
            SwitchListTile(
              title: const Text("Show Small Camera Popup"),
              subtitle: const Text("Check yourself while reading"),
              value: _showCameraPreview,
              onChanged: (v) => setState(() => _showCameraPreview = v),
              secondary: const Icon(Icons.camera_alt),
            ),
            SwitchListTile(
              title: const Text("Record while Prompting"),
              subtitle: const Text("Keep a video of your performance"),
              value: _recordVideo,
              onChanged: (v) => setState(() => _recordVideo = v),
              secondary: const Icon(Icons.videocam),
            ),

            // Color Schemes
            const SizedBox(height: 10),
            const Text("Color Scheme", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: _schemes.map((scheme) {
                bool isSelected = _textColor == scheme['text'] && _backgroundColor == scheme['bg'];
                return ChoiceChip(
                  label: Text(scheme['name']),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _textColor = scheme['text'];
                        _backgroundColor = scheme['bg'];
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text("Apply Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class PrompterScreen extends StatefulWidget {
  final String text;
  final TeleprompterSettings initialSettings;
  final ValueChanged<TeleprompterSettings> onSettingsChanged;

  const PrompterScreen({
    Key? key,
    required this.text,
    required this.initialSettings,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  State<PrompterScreen> createState() => _PrompterScreenState();
}

class _PrompterScreenState extends State<PrompterScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _scrollAnimation;

  late TeleprompterSettings _settings;
  late int _currentSpeed;
  bool _isPlaying = false;
  bool _showControls = true;

  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isRecording = false;
  XFile? _recordedVideoFile;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _currentSpeed = _settings.scrollSpeed;
    
    _animationController = AnimationController(vsync: this);
    _animationController.addListener(_onAnimate);

    _initCameraIfNeeded();
  }

  void _initCameraIfNeeded() async {
    bool needsCamera = _settings.showCameraPreview || _settings.recordVideo;
    if (needsCamera && globalCameras.isNotEmpty) {
      if (_cameraController != null) return; // already init

      CameraDescription? frontCam;
      try {
        frontCam = globalCameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
      } catch (e) {
        frontCam = globalCameras.first;
      }
      
      _cameraController = CameraController(
        frontCam, 
        ResolutionPreset.low, 
        enableAudio: true, // Audio enabled for recording
      );
      try {
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraReady = true;
          });
        }
      } catch (e) {
        debugPrint("Camera error: $e");
      }
    } else {
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
        if (mounted) setState(() => _isCameraReady = false);
      }
    }
  }

  void _updateSettings(TeleprompterSettings newSettings) {
    bool cameraToggled = (_settings.showCameraPreview != newSettings.showCameraPreview) || 
                        (_settings.recordVideo != newSettings.recordVideo);
    setState(() {
      _settings = newSettings;
    });
    widget.onSettingsChanged(newSettings);
    if (cameraToggled) {
      _initCameraIfNeeded();
    }
  }

  void _openSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SettingsModal(
          initialSettings: _settings,
          onApply: (newSettings) {
             _updateSettings(newSettings);
             Navigator.pop(context);
          }
        );
      },
    );
  }

  void _onAnimate() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollAnimation.value);
    }
  }

  void _calculateAndStartScroll() {
    if (!_scrollController.hasClients) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final remainingDistance = maxScrollExtent - currentOffset;

    if (remainingDistance <= 0) {
      setState(() => _isPlaying = false);
      return;
    }

    final pixelsPerSecond = _currentSpeed * 8.0; 
    final durationSeconds = remainingDistance / pixelsPerSecond;

    _animationController.duration = Duration(milliseconds: (durationSeconds * 1000).toInt());

    _scrollAnimation = Tween<double>(
      begin: currentOffset,
      end: maxScrollExtent,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    _animationController.forward(from: 0.0);

    if (_settings.recordVideo && _isCameraReady && !_isRecording) {
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      await _cameraController!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint("Start recording error: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return;
    try {
      final file = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _recordedVideoFile = file;
      });
      _showVideoPreview();
    } catch (e) {
      debugPrint("Stop recording error: $e");
    }
  }

  void _showVideoPreview() {
    if (_recordedVideoFile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPreviewScreen(file: File(_recordedVideoFile!.path)),
      ),
    );
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _showControls = false;
        _calculateAndStartScroll();
      } else {
        _animationController.stop();
        if (_isRecording) {
          _stopRecording();
        }
        _showControls = true;
      }
    });
  }

  void _adjustSpeed(int delta) {
    setState(() {
      _currentSpeed = (_currentSpeed + delta).clamp(1, 40);
    });
    if (_isPlaying) {
      _animationController.stop();
      _calculateAndStartScroll();
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Color _getColorForName(String name) {
    final List<Color> palette = [
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.tealAccent,
      Colors.cyanAccent,
      Colors.amberAccent,
      Colors.deepOrangeAccent,
      Colors.indigoAccent,
    ];
    // Simple deterministic hash
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return palette[hash.abs() % palette.length];
  }

  Color _getTagColor(String tag) {
    // Check for hex code like #FFFFFF
    final hexRegex = RegExp(r'#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})');
    final hexMatch = hexRegex.firstMatch(tag);
    if (hexMatch != null) {
      try {
        String hex = hexMatch.group(0)!.replaceFirst('#', '');
        if (hex.length == 3) {
          hex = hex.split('').map((c) => c + c).join();
        }
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    final tagContent = tag.replaceAll('[', '').replaceAll(']', '').trim();
    
    // Extract name from formats like [Chorus: Singer] or [Verse 1 | Singer]
    String singerKey = tagContent;
    if (tagContent.contains(':')) {
      singerKey = tagContent.split(':')[1].trim();
    } else if (tagContent.contains('|')) {
      singerKey = tagContent.split('|')[1].trim();
    }
    
    // If we have a singer key, use it. Otherwise use the whole tag (like [Chorus])
    if (singerKey.isEmpty) singerKey = tagContent;
    
    // Check keywords if it's just a section tag without a name
    final lower = singerKey.toLowerCase();
    if (lower.contains('chorus')) return Colors.blueAccent;
    if (lower.contains('verse')) return Colors.greenAccent;
    if (lower.contains('bridge')) return Colors.orangeAccent;
    if (lower.contains('outro')) return Colors.purpleAccent;
    if (lower.contains('intro')) return Colors.tealAccent;

    return _getColorForName(singerKey);
  }

  Color _adjustColorForBackground(Color color) {
    final bgBrightness = ThemeData.estimateBrightnessForColor(_settings.backgroundColor);
    final hsl = HSLColor.fromColor(color);
    if (bgBrightness == Brightness.light) {
      // Background is light, make color darker if it's too bright/light
      if (hsl.lightness > 0.7) {
        return hsl.withLightness(0.5).toColor();
      }
    } else {
      // Background is dark, make color lighter if it's too dark
      if (hsl.lightness < 0.3) {
        return hsl.withLightness(0.7).toColor();
      }
    }
    return color;
  }

  TextSpan _buildTextSpans(String text) {
    final List<TextSpan> spans = [];
    final lines = text.split('\n');
    
    Color? currentSectionColor;
    final parenRegExp = RegExp(r'(\(.*?\))');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      
      if (trimmedLine.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      // Detection of [Tag]
      if (trimmedLine.startsWith('[') && trimmedLine.contains(']')) {
        currentSectionColor = _adjustColorForBackground(_getTagColor(trimmedLine));
        spans.add(TextSpan(
          text: line.toUpperCase() + (i < lines.length - 1 ? '\n' : ''),
          style: TextStyle(
            color: currentSectionColor,
            fontWeight: FontWeight.w900,
            fontSize: _settings.fontSize * 0.55, // Smaller, uppercase header style
            letterSpacing: 2.5,
            height: 3.0,
          ),
        ));
      } 
      // Normal lyrics (potentially with mixed parentheses)
      else {
        final List<TextSpan> lineSpans = [];
        int lastMatchEnd = 0;
        final Color baseColor = currentSectionColor ?? _settings.textColor;
        
        for (final Match match in parenRegExp.allMatches(line)) {
          if (match.start > lastMatchEnd) {
            lineSpans.add(TextSpan(
              text: line.substring(lastMatchEnd, match.start),
              style: TextStyle(
                color: baseColor,
                fontSize: _settings.fontSize,
                fontWeight: currentSectionColor != null ? FontWeight.w500 : FontWeight.w600,
              ),
            ));
          }
          lineSpans.add(TextSpan(
            text: match.group(0),
            style: TextStyle(
              color: baseColor.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
              fontSize: _settings.fontSize * 0.85,
              fontWeight: FontWeight.w400,
            ),
          ));
          lastMatchEnd = match.end;
        }
        
        if (lastMatchEnd < line.length) {
          lineSpans.add(TextSpan(
            text: line.substring(lastMatchEnd),
            style: TextStyle(
              color: baseColor,
              fontSize: _settings.fontSize,
              fontWeight: currentSectionColor != null ? FontWeight.w500 : FontWeight.w600,
            ),
          ));
        }
        
        lineSpans.add(TextSpan(text: (i < lines.length - 1 ? '\n' : '')));
        spans.addAll(lineSpans);
      }
    }
    
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _settings.backgroundColor,
      body: GestureDetector(
        onTap: () {
          if (!_isPlaying) {
            _togglePlayPause();
          } else {
            _toggleControls();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // The scrolling text area
            Scrollbar(
              controller: _scrollController,
              child: NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  if (notification.direction != ScrollDirection.idle && _isPlaying) {
                    _togglePlayPause();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text.rich(
                          _buildTextSpans(widget.text),
                          textAlign: TextAlign.center,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.6),
                    ],
                  ),
                ),
              ),
            ),

            // Reading Focus Line overlay
            if (_settings.showFocusLine)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.4,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: _settings.fontSize * 1.5,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.redAccent.withValues(alpha: 0.8), width: 8),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.redAccent.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.center,
                      ),
                    ),
                  ),
                ),
              ),

            // Camera popup preview
            if (_settings.showCameraPreview && _isCameraReady && _cameraController != null)
              Positioned(
                bottom: 20,
                right: 20,
                child: IgnorePointer(
                  child: Container(
                    width: 140,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 8))
                      ],
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(3.14159), // Mirror selfie preview horizontally
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
              ),

            // Controls overlay
            if (_showControls)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.8),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _openSettingsDialog,
                                icon: const Icon(Icons.settings, color: Colors.black, size: 28),
                                label: const Text("More Options", style: TextStyle(color: Colors.black, fontSize: 18)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 48, color: Colors.black),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),

                        // Center Play Button overlay visualization
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Icon(
                            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            size: 100,
                            color: Colors.black.withValues(alpha: 0.8),
                          ),
                        ),

                        // Bottom Controls
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2)
                              ],
                              border: Border.all(color: Colors.black12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.black),
                                  iconSize: 36,
                                  onPressed: () => _adjustSpeed(-1),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  children: [
                                    const Text("SPEED", style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
                                    Text(
                                      "$_currentSpeed",
                                      style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.black),
                                  iconSize: 36,
                                  onPressed: () => _adjustSpeed(1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class VideoPreviewScreen extends StatefulWidget {
  final File file;
  const VideoPreviewScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Recording Preview", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _initialized && _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
          });
        },
        backgroundColor: Colors.white,
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.black,
        ),
      ),
    );
  }
}
