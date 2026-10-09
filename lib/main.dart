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
      title: 'J.A.R.V.I.S. Stark HUD',
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
      home: const SplashScreen(),
    );
  }
}

// --- ANDROID NATIVE METHOD CHANNEL ---
class AndroidNativeBridge {
  static const MethodChannel _channel = MethodChannel('com.starkindustries.jarvis/native');

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

// --- CUSTOM ARC REACTOR PAINTER (Tony Stark Style) ---
class ArcReactorPainter extends CustomPainter {
  final double animationValue;
  ArcReactorPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final paintOuter = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final paintGlow = Paint()
      ..color = Colors.cyan.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Draw outer pulsing rings
    canvas.drawCircle(center, radius * 0.9, paintGlow);
    canvas.drawCircle(center, radius * 0.9, paintOuter);

    // Draw rotating tech segments
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animationValue * 2 * math.pi);

    final paintSegments = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (int i = 0; i < 8; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius * 0.7),
        (i * math.pi / 4) + 0.1,
        math.pi / 4 - 0.2,
        false,
        paintSegments,
      );
    }
    canvas.restore();

    // Inner core ring
    final paintInner = Paint()
      ..color = Colors.blueAccent.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius * 0.45, paintInner);

    // Center core bright spot
    final paintCore = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.15, paintCore);
  }

  @override
  bool shouldRepaint(covariant ArcReactorPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// --- 1. SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.storage,
      Permission.notification,
    ].request();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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
      backgroundColor: const Color(0xFF010409),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(140, 140),
                  painter: ArcReactorPainter(animationValue: _controller.value),
                );
              },
            ),
            const SizedBox(height: 35),
            const Text(
              'J.A.R.V.I.S.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 6.0,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'STARK INDUSTRIES OMEGA v20.0',
              style: TextStyle(fontSize: 11, color: Colors.cyanAccent.withOpacity(0.7), letterSpacing: 3.0),
            ),
            const SizedBox(height: 45),
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent)),
          ],
        ),
      ),
    );
  }
}

// --- 2. LOGIN SCREEN ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010409),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117).withOpacity(0.95),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 30, spreadRadius: 3),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint, size: 60, color: Colors.cyanAccent),
                const SizedBox(height: 16),
                const Text(
                  'MARK VII BIOMETRIC LOCK',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.cyanAccent, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                Text('LEVEL 10 OMEGA CLEARANCE', style: TextStyle(fontSize: 10, color: Colors.cyanAccent.withOpacity(0.6))),
                const SizedBox(height: 24),
                TextField(
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'DESIGNATED USER',
                    labelStyle: TextStyle(color: Colors.cyanAccent),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                  controller: TextEditingController(text: 'Tony Stark'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: const Color(0xFF010409),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  child: const Text('ENGAGE STARK HUD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- MAIN STARK HUD HOME CONTAINER ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  bool _isCharging = false;
  String _networkStatus = 'Checking...';
  
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _lastWords = '';
  String _languageCode = 'en-US';

  String _geminiApiKey = '';
  String _weatherApiKey = '';
  
  List<Map<String, dynamic>> _chatHistory = [];
  List<dynamic> _installedApps = [];
  Map<String, dynamic>? _weatherData;

  late AnimationController _reactorController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reactorController = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat();
    _initDeviceSensors();
    _initSpeechAndTts();
    _loadSettings();
    _fetchInstalledApps();
    _chatHistory.add({
      'sender': 'jarvis',
      'text': 'Stark Industries Neural Net online, sir. All tactical systems fully operational.',
      'time': DateFormat('hh:mm a').format(DateTime.now()),
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reactorController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopListening();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiApiKey = prefs.getString('gemini_api_key') ?? '';
      _weatherApiKey = prefs.getString('weather_api_key') ?? '';
    });
  }

  Future<void> _initDeviceSensors() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      setState(() {
        _batteryLevel = level;
        _isCharging = state == BatteryState.charging;
      });

      _battery.onBatteryStateChanged.listen((BatteryState state) async {
        final level = await _battery.batteryLevel;
        setState(() {
          _batteryLevel = level;
          _isCharging = state == BatteryState.charging;
        });
      });

      final connectivityResult = await (Connectivity().checkConnectivity());
      setState(() {
        _networkStatus = connectivityResult == ConnectivityResult.wifi
            ? 'Quantum WiFi'
            : connectivityResult == ConnectivityResult.mobile
                ? 'Stark 5G Uplink'
                : 'Offline';
      });
    } catch (e) {
      print("Sensor error: $e");
    }
  }

  Future<void> _initSpeechAndTts() async {
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage(_languageCode);
    await _flutterTts.setSpeechRate(1.0);
  }

  Future<void> _fetchInstalledApps() async {
    final apps = await AndroidNativeBridge.getInstalledApps();
    setState(() {
      _installedApps = apps;
    });
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        print('Speech Error: $error');
        setState(() => _isListening = false);
      },
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
          });
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _stopListening();
            _handleUserCommand(result.recognizedWords);
          }
        },
        localeId: _languageCode,
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _fetchWeather(String city) async {
    if (_weatherApiKey.isEmpty) {
      _addJarvisMessage("Weather API Key missing. Please configure WEATHER_API_KEY in Settings.");
      return;
    }
    try {
      final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?q=$city&units=metric&appid=$_weatherApiKey');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _weatherData = data);
        final temp = data['main']['temp'].round();
        final desc = data['weather'][0]['description'];
        final reply = "Current temperature in $city is $temp°C with $desc.";
        _addJarvisMessage(reply);
        _speak(reply);
      } else {
        _addJarvisMessage("Unable to fetch weather data from server.");
      }
    } catch (e) {
      _addJarvisMessage("Weather uplink error.");
    }
  }

  Future<void> _callGeminiApi(String prompt) async {
    if (_geminiApiKey.isEmpty) {
      _addJarvisMessage("GEMINI_API_KEY is missing! Please enter your key in Settings tab.");
      return;
    }
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=$_geminiApiKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [{"text": prompt}]
            }
          ],
          "systemInstruction": {
            "parts": [{"text": "You are JARVIS, an advanced Stark Industries AI assistant. Respond with British precision."}]
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        _addJarvisMessage(text);
        _speak(text);
      } else {
        _addJarvisMessage("Gemini API server error.");
      }
    } catch (e) {
      _addJarvisMessage("Neural uplink disruption.");
    }
  }

  void _addJarvisMessage(String text) {
    setState(() {
      _chatHistory.add({
        'sender': 'jarvis',
        'text': text,
        'time': DateFormat('hh:mm a').format(DateTime.now()),
      });
    });
  }

  void _handleUserCommand(String command) async {
    if (command.trim().isEmpty) return;

    setState(() {
      _chatHistory.add({
        'sender': 'user',
        'text': command,
        'time': DateFormat('hh:mm a').format(DateTime.now()),
      });
    });

    final lower = command.toLowerCase();

    // DYNAMIC APP LAUNCHER
    if (lower.startsWith('open ')) {
      String appQuery = lower.replaceFirst('open ', '').trim();
      dynamic matchedApp;
      for (var app in _installedApps) {
        String name = (app['name'] ?? '').toString().toLowerCase();
        if (name.contains(appQuery)) {
          matchedApp = app;
          break;
        }
      }

      if (matchedApp != null) {
        String appName = matchedApp['name'];
        String pkgName = matchedApp['packageName'];
        _addJarvisMessage("Launching $appName.");
        _speak("Opening $appName, sir.");
        await AndroidNativeBridge.openAppPackage(pkgName);
        return;
      }
    }

    if (lower.contains('weather')) {
      await _fetchWeather('Bhadrak');
    } else if (lower.contains('battery')) {
      final msg = "Battery level is $_batteryLevel percent, ${_isCharging ? 'charging' : 'discharging'}.";
      _addJarvisMessage(msg);
      _speak(msg);
    } else if (lower.contains('time')) {
      final nowTime = DateFormat('hh:mm:ss a').format(DateTime.now());
      final msg = "Current system device time is $nowTime, sir.";
      _addJarvisMessage(msg);
      _speak(msg);
    } else {
      await _callGeminiApi(command);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeDashboard(),
      _buildVoiceScreen(),
      _buildChatScreen(),
      _buildAppsScreen(),
      _buildSettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117).withOpacity(0.95),
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _reactorController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(28, 28),
                  painter: ArcReactorPainter(animationValue: _reactorController.value),
                );
              },
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('J.A.R.V.I.S.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.5, color: Colors.cyanAccent)),
                Text('STARK HUD v20.0', style: TextStyle(fontSize: 9, color: Colors.cyan)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_languageCode == 'en-US' ? Icons.language : Icons.translate, color: Colors.cyanAccent),
            onPressed: () {
              setState(() {
                _languageCode = _languageCode == 'en-US' ? 'hi-IN' : 'en-US';
                _flutterTts.setLanguage(_languageCode);
              });
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF0D1117),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'HUD'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Voice'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Apps'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHomeDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // MAIN HOLOGRAPHIC ARC REACTOR CARD
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117).withOpacity(0.85),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 25, spreadRadius: 2),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _currentIndex = 1),
                  child: AnimatedBuilder(
                    animation: _reactorController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(120, 120),
                        painter: ArcReactorPainter(animationValue: _reactorController.value),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text('ARC REACTOR CORE: ONLINE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.cyanAccent, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text('Tap reactor core to engage voice command center', style: TextStyle(fontSize: 10, color: Colors.cyanAccent.withOpacity(0.6))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _metricCard('BATTERY CORE', '$_batteryLevel%', _isCharging ? 'Charging AC' : 'Discharging', Icons.bolt),
              _metricCard('NETWORK UPLINK', _networkStatus, 'Active Signal', Icons.wifi),
              _metricCard('AI ENGINE', 'Gemini 3 Flash', 'Online', Icons.memory),
              _metricCard('QUANTUM TIME', DateFormat('hh:mm a').format(DateTime.now()), 'Synchronized', Icons.access_time),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _actionButton('WhatsApp', () => AndroidNativeBridge.openWhatsApp('', '')),
              _actionButton('YouTube', () => AndroidNativeBridge.openAppPackage('com.google.android.youtube')),
              _actionButton('Chrome', () => AndroidNativeBridge.openAppPackage('com.android.chrome')),
              _actionButton('Calculator', () => AndroidNativeBridge.openAppPackage('com.android.calculator2')),
              _actionButton('Weather', () => _fetchWeather('Bhadrak')),
              _actionButton('Camera', () => AndroidNativeBridge.openAppPackage('com.android.camera2')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 9, color: Colors.cyanAccent)),
              Icon(icon, size: 14, color: Colors.cyanAccent),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(subtitle, style: const TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.cyanAccent,
        side: BorderSide(color: Colors.cyanAccent.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildVoiceScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedBuilder(
              animation: _reactorController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.5),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    size: const Size(160, 160),
                    painter: ArcReactorPainter(animationValue: _reactorController.value),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 35),
          Text(_isListening ? 'LISTENING TO COMMAND, SIR...' : 'TAP REACTOR TO SPEAK', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.cyanAccent, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text('"$_lastWords"', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75))),
          ),
        ],
      ),
    );
  }

  Widget _buildChatScreen() {
    final TextEditingController textController = TextEditingController();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _chatHistory.length,
            itemBuilder: (context, index) {
              final msg = _chatHistory[index];
              final isUser = msg['sender'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.cyan.withOpacity(0.2) : const Color(0xFF0D1117),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg['text'], style: const TextStyle(fontSize: 13, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(msg['time'], style: const TextStyle(fontSize: 8, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          color: const Color(0xFF0D1117),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Ask Gemini AI or command Jarvis...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.cyanAccent),
                onPressed: () {
                  if (textController.text.isNotEmpty) {
                    _handleUserCommand(textController.text);
                    textController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppsScreen() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _installedApps.length,
      itemBuilder: (context, index) {
        final app = _installedApps[index];
        return Card(
          color: const Color(0xFF0D1117),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.cyanAccent.withOpacity(0.3))),
          child: ListTile(
            title: Text(app['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(app['packageName'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 10)),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.cyanAccent),
              onPressed: () => AndroidNativeBridge.openAppPackage(app['packageName']),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsScreen() {
    final TextEditingController geminiController = TextEditingController(text: _geminiApiKey);
    final TextEditingController weatherController = TextEditingController(text: _weatherApiKey);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text('API CONFIGURATION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
          const SizedBox(height: 16),
          TextField(
            controller: geminiController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'GEMINI_API_KEY',
              labelStyle: TextStyle(color: Colors.cyanAccent),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: weatherController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'WEATHER_API_KEY (OpenWeather)',
              labelStyle: TextStyle(color: Colors.cyanAccent),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: const Color(0xFF010409)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('gemini_api_key', geminiController.text);
              await prefs.setString('weather_api_key', weatherController.text);
              setState(() {
                _geminiApiKey = geminiController.text;
                _weatherApiKey = weatherController.text;
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Keys saved successfully!')));
            },
            child: const Text('SAVE CONFIGURATION', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
