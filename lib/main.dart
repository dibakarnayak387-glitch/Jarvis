import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF010409),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'J.A.R.V.I.S. Ultimate HUD',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF010409),
        primaryColor: Colors.cyanAccent,
        fontFamily: 'monospace',
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.blueAccent,
          surface: Color(0xFF0D1117),
        ),
      ),
      home: const GiantArcReactorScreen(),
    );
  }
}

// --- ANDROID NATIVE METHOD CHANNEL ---
class AndroidNativeBridge {
  static const MethodChannel _channel = MethodChannel('com.starkindustries.jarvis/native');

  static Future<bool> startForegroundService() async {
    try {
      final bool result = await _channel.invokeMethod('startForegroundService');
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> openWhatsApp(String phone, String message) async {
    try {
      final bool result = await _channel.invokeMethod('openWhatsApp', {'phone': phone, 'message': message});
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> openAppPackage(String packageName) async {
    try {
      final bool result = await _channel.invokeMethod('openAppPackage', {'packageName': packageName});
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> getInstalledApps() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getInstalledAppsList');
      return result;
    } catch (e) {
      return [];
    }
  }
}

// --- GIANT CUSTOM ARC REACTOR PAINTER ---
class GiantArcReactorPainter extends CustomPainter {
  final double animationValue;
  GiantArcReactorPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final paintGlow = Paint()
      ..color = Colors.cyan.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final paintOuter = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // Outer rings
    canvas.drawCircle(center, radius * 0.95, paintGlow);
    canvas.drawCircle(center, radius * 0.95, paintOuter);

    // Rotating tech gears
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animationValue * 2 * math.pi);

    final paintGears = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    for (int i = 0; i < 12; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius * 0.75),
        (i * math.pi / 6) + 0.05,
        math.pi / 6 - 0.1,
        false,
        paintGears,
      );
    }
    canvas.restore();

    // Inner plasma ring
    final paintInner = Paint()
      ..color = Colors.blueAccent.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius * 0.45, paintInner);

    // Center core energy
    final paintCore = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, radius * 0.2, paintCore);
  }

  @override
  bool shouldRepaint(covariant GiantArcReactorPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// --- GIANT SINGLE SCREEN HUD WITH HOLOGRAPHIC PROJECTOR ---
class GiantArcReactorScreen extends StatefulWidget {
  const GiantArcReactorScreen({Key? key}) : super(key: key);

  @override
  State<GiantArcReactorScreen> createState() => _GiantArcReactorScreenState();
}

class _GiantArcReactorScreenState extends State<GiantArcReactorScreen> with TickerProviderStateMixin {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  bool _isCharging = false;
  String _networkStatus = 'Checking...';

  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _lastCommand = 'JARVIS CORE STANDBY';

  String _geminiApiKey = '';
  List<dynamic> _installedApps = [];
  
  // Hologram State
  bool _isHologramActive = false;
  double _hologramScale = 1.0;
  Offset _hologramOffset = Offset.zero;

  late AnimationController _reactorController;

  @override
  void initState() {
    super.initState();
    _reactorController = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat();
    _initSystem();
  }

  Future<void> _initSystem() async {
    await AndroidNativeBridge.startForegroundService();
    
    final prefs = await SharedPreferences.getInstance();
    _geminiApiKey = prefs.getString('gemini_api_key') ?? '';

    _installedApps = await AndroidNativeBridge.getInstalledApps();

    try {
      _batteryLevel = await _battery.batteryLevel;
      _isCharging = (await _battery.batteryState) == BatteryState.charging;
      _battery.onBatteryStateChanged.listen((state) async {
        _batteryLevel = await _battery.batteryLevel;
        _isCharging = state == BatteryState.charging;
        setState(() {});
      });

      final conn = await Connectivity().checkConnectivity();
      _networkStatus = conn == ConnectivityResult.wifi ? 'Quantum WiFi' : 'Stark 5G';
    } catch (e) {
      print("Init error: $e");
    }

    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(1.0);
    setState(() {});
  }

  @override
  void dispose() {
    _reactorController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() => _lastCommand = result.recognizedWords);
            if (result.finalResult && result.recognizedWords.isNotEmpty) {
              _handleCommand(result.recognizedWords);
            }
          },
        );
      }
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _handleCommand(String cmd) async {
    final lower = cmd.toLowerCase();
    setState(() => _lastCommand = cmd);

    if (lower.startsWith('open ')) {
      String appQuery = lower.replaceFirst('open ', '').trim();
      for (var app in _installedApps) {
        if ((app['name'] ?? '').toString().toLowerCase().contains(appQuery)) {
          _speak("Opening ${app['name']}, sir.");
          await AndroidNativeBridge.openAppPackage(app['packageName']);
          return;
        }
      }
      _speak("Application not found, sir.");
    } else if (lower.contains('battery')) {
      final msg = "Battery is at $_batteryLevel percent, ${_isCharging ? 'charging' : 'discharging'}.";
      _speak(msg);
    } else if (lower.contains('hologram')) {
      setState(() => _isHologramActive = true);
      _speak("Stark Holographic Projector engaged, sir. Use air gestures to manipulate.");
    } else if (_geminiApiKey.isNotEmpty) {
      try {
        final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=$_geminiApiKey');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [{"role": "user", "parts": [{"text": cmd}]}],
            "systemInstruction": {"parts": [{"text": "You are JARVIS, Tony Stark's advanced AI. Respond with British precision."}]}
          }),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'];
          _speak(text);
        }
      } catch (e) {
        _speak("Neural uplink error.");
      }
    } else {
      _speak("Gemini API key not configured in settings.");
    }
  }

  void _showSettingsDialog() {
    final TextEditingController keyController = TextEditingController(text: _geminiApiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.cyanAccent)),
        title: const Text('STARK CONFIGURATION', style: TextStyle(color: Colors.cyanAccent, fontSize: 14, letterSpacing: 2)),
        content: TextField(
          controller: keyController,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(
            labelText: 'GEMINI API KEY',
            labelStyle: TextStyle(color: Colors.cyanAccent),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('gemini_api_key', keyController.text);
              setState(() => _geminiApiKey = keyController.text);
              Navigator.pop(context);
            },
            child: const Text('SAVE', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010409),
      body: SafeArea(
        child: Stack(
          children: [
            // MAIN GIANT ARC REACTOR UI
            Column(
              children: [
                // Top Stark Status Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('J.A.R.V.I.S.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.cyanAccent)),
                          Text('OMEGA STARK HUD v25.0', style: TextStyle(fontSize: 9, color: Colors.cyan, letterSpacing: 1.5)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.cyanAccent),
                        onPressed: _showSettingsDialog,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // GIANT ARC REACTOR CENTERPIECE
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedBuilder(
                    animation: _reactorController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.6),
                              blurRadius: 60,
                              spreadRadius: 15,
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          size: const Size(260, 260),
                          painter: GiantArcReactorPainter(animationValue: _reactorController.value),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  _isListening ? 'LISTENING TO COMMAND...' : 'TAP REACTOR CORE TO ENGAGE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isListening ? Colors.redAccent : Colors.cyanAccent, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    '"$_lastCommand"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                  ),
                ),
                const Spacer(),
                // System Metrics Bottom Bar
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117).withOpacity(0.9),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricItem('BATTERY', '$_batteryLevel%', _isCharging ? 'Charging' : 'Normal'),
                      _metricItem('NETWORK', _networkStatus, 'Online'),
                      _metricItem('QUANTUM TIME', DateFormat('hh:mm a').format(DateTime.now()), 'Synced'),
                    ],
                  ),
                ),
              ],
            ),

            // HOLOGRAPHIC PROJECTOR OVERLAY (AIR GESTURE ZOOM/PAN)
            if (_isHologramActive)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  child: Stack(
                    children: [
                      Center(
                        child: InteractiveViewer(
                          transformationController: TransformationController(),
                          minScale: 0.5,
                          maxScale: 5.0,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.cyanAccent, width: 2),
                              color: Colors.cyan.withOpacity(0.1),
                              boxShadow: [
                                BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 30),
                              ],
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.hexagon_outlined, size: 80, color: Colors.cyanAccent),
                                  SizedBox(height: 10),
                                  Text('STARK HOLOGRAPHIC MATRIX', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, letterSpacing: 2)),
                                  Text('Pinch / Drag to manipulate in air', style: TextStyle(color: Colors.grey, fontSize: 9)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 40,
                        right: 20,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.cyanAccent, size: 30),
                          onPressed: () => setState(() => _isHologramActive = false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String label, String val, String sub) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.cyanAccent, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(sub, style: const TextStyle(fontSize: 7, color: Colors.grey)),
      ],
    );
  }
}
