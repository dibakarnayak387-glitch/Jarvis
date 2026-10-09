import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF020617),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'J.A.R.V.I.S.',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF020617),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
        ),
        fontFamily: 'monospace',
      ),
      home: const HomeScreen(),
    );
  }
}

class AndroidNativeBridge {
  static const MethodChannel _channel =
      MethodChannel('com.starkindustries.jarvis/native');

  static Future<bool> openWhatsApp({String phone = '', String message = ''}) async {
    try {
      return await _channel.invokeMethod<bool>('openWhatsApp', {
            'phone': phone,
            'message': message,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> openWhatsAppForContact(
      String contactName, String message) async {
    try {
      final result = await _channel.invokeMethod<dynamic>(
        'openWhatsAppForContact',
        {'contactName': contactName, 'message': message},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      return {'success': false, 'status': 'error', 'message': '$e'};
    }
  }

  static Future<bool> openAppPackage(String packageName) async {
    try {
      return await _channel.invokeMethod<bool>('openAppPackage', {
            'packageName': packageName,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openCamera() async {
    try {
      return await _channel.invokeMethod<bool>('openCamera') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openAppByName(String name) async {
    try {
      return await _channel.invokeMethod<bool>('openAppByName', {'name': name}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> getInstalledApps() async {
    try {
      return await _channel.invokeMethod<List<dynamic>>('getInstalledAppsList') ?? [];
    } catch (_) {
      return [];
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _ListenState { idle, listening, processing, speaking }

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  StreamSubscription<BatteryState>? _batterySubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _restartTimer;

  int _currentIndex = 0;
  int _batteryLevel = 0;
  bool _isCharging = false;
  String _networkStatus = 'Checking...';
  String _lastWords = '';
  String _languageCode = 'en-US';
  String _statusText = 'INITIALIZING';
  _ListenState _listenState = _ListenState.idle;
  bool _continuousListening = true;
  bool _speechAvailable = false;
  bool _commandInProgress = false;
  bool _manualStop = false;

  String _geminiApiKey = '';
  String _weatherApiKey = '';

  List<Map<String, dynamic>> _chatHistory = [];
  List<dynamic> _installedApps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatHistory.add(_message('jarvis', 'JARVIS system online, sir.'));
    _initialize();
  }

  Map<String, dynamic> _message(String sender, String text) => {
        'sender': sender,
        'text': text,
        'time': DateFormat('hh:mm a').format(DateTime.now()),
      };

  Future<void> _initialize() async {
    await _loadSettings();
    await _requestPermissions();
    await _initDeviceSensors();
    await _initTts();
    await _initSpeech();
    await _fetchInstalledApps();
    if (_speechAvailable && _continuousListening) {
      await _startListening();
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    // Contact permission is requested only when a contact-based WhatsApp command is used.
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _geminiApiKey = prefs.getString('gemini_api_key') ?? '';
      _weatherApiKey = prefs.getString('weather_api_key') ?? '';
    });
  }

  Future<void> _initDeviceSensors() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
          _isCharging = state == BatteryState.charging || state == BatteryState.full;
        });
      }

      _batterySubscription = _battery.onBatteryStateChanged.listen((state) async {
        final level = await _battery.batteryLevel;
        if (!mounted) return;
        setState(() {
          _batteryLevel = level;
          _isCharging = state == BatteryState.charging || state == BatteryState.full;
        });
      });

      final result = await _connectivity.checkConnectivity();
      _setNetwork(result);
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_setNetwork);
    } catch (e) {
      _networkStatus = 'Unavailable';
    }
  }

  void _setNetwork(ConnectivityResult result) {
    String value;
    if (result == ConnectivityResult.wifi) {
      value = 'Wi-Fi connected';
    } else if (result == ConnectivityResult.mobile) {
      value = 'Mobile data connected';
    } else if (result == ConnectivityResult.ethernet) {
      value = 'Ethernet connected';
    } else {
      value = 'Offline';
    }
    if (mounted) setState(() => _networkStatus = value);
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(_languageCode);
    await _tts.setSpeechRate(0.92);
    await _tts.setPitch(1.0);
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) {
        if (mounted) setState(() => _statusText = 'SPEECH ERROR');
        if (_continuousListening && !_manualStop && !_commandInProgress) {
          _scheduleRestart();
        }
      },
    );
    if (mounted) setState(() => _statusText = _speechAvailable ? 'READY' : 'SPEECH UNAVAILABLE');
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'listening') {
      setState(() {
        _listenState = _ListenState.listening;
        _statusText = 'LISTENING';
      });
    } else if (status == 'notListening') {
      if (_listenState == _ListenState.listening) {
        setState(() => _listenState = _ListenState.idle);
      }
      if (_continuousListening && !_manualStop && !_commandInProgress) {
        _scheduleRestart();
      }
    }
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _continuousListening && !_manualStop && !_commandInProgress) {
        _startListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (!_speechAvailable || _speech.isListening || _commandInProgress || !mounted) return;
    _manualStop = false;
    _restartTimer?.cancel();
    setState(() {
      _listenState = _ListenState.listening;
      _statusText = 'LISTENING';
    });

    await _speech.listen(
      localeId: _languageCode,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty || !mounted) return;
        setState(() => _lastWords = text);
        if (result.finalResult) {
          _handleUserCommand(text);
        }
      },
    );
  }

  Future<void> _stopListening() async {
    _manualStop = true;
    _restartTimer?.cancel();
    await _speech.stop();
    if (mounted) {
      setState(() {
        _listenState = _ListenState.idle;
        _statusText = 'IDLE';
      });
    }
  }

  String _normalize(String input) {
    var text = input.toLowerCase().trim();
    const replacements = {
      'jervis': 'jarvis',
      'jarvis ji': 'jarvis',
      'hey jarvis ji': 'hey jarvis',
      'whatsapp kholo': 'whatsapp open',
      'whatsapp khol do': 'whatsapp open',
      'whatsapp chalao': 'whatsapp open',
      'youtube kholo': 'youtube open',
      'youtube chalao': 'youtube open',
      'chrome kholo': 'chrome open',
      'chrome chalao': 'chrome open',
      'camera kholo': 'camera open',
      'camera chalao': 'camera open',
      'calculator kholo': 'calculator open',
      'calculator chalao': 'calculator open',
    };
    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });
    return text.replaceAll(RegExp(r'[.,!?;:()\[\]{}]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _containsWakeWord(String text) {
    final normalized = _normalize(text);
    const words = ['hey jarvis', 'jarvis', 'hi gpt', 'gpt'];
    return words.any((word) => normalized == word || normalized.startsWith('$word ') || normalized.contains(' $word '));
  }

  String _removeWakeWord(String text) {
    var result = _normalize(text);
    for (final word in ['hey jarvis', 'hi gpt', 'jarvis', 'gpt']) {
      result = result.replaceFirst(RegExp('^${RegExp.escape(word)}\\s*'), '').trim();
    }
    return result;
  }

  Future<void> _handleUserCommand(String rawCommand) async {
    if (_commandInProgress || rawCommand.trim().isEmpty) return;
    final normalized = _normalize(rawCommand);
    final hasWake = _containsWakeWord(normalized);

    // Ignore unrelated ambient speech while using wake-word mode. Direct commands are
    // still accepted when they clearly match a supported local action.
    final directLocal = _looksLikeLocalCommand(normalized);
    if (_continuousListening && !hasWake && !directLocal) return;

    _commandInProgress = true;
    await _speech.stop();
    if (mounted) {
      setState(() {
        _listenState = _ListenState.processing;
        _statusText = 'PROCESSING';
        _chatHistory.add(_message('user', rawCommand));
      });
    }

    final command = hasWake ? _removeWakeWord(normalized) : normalized;
    try {
      if (command.isEmpty) {
        await _respond('Yes sir. How can I help?');
      } else {
        await _executeCommand(command);
      }
    } finally {
      _commandInProgress = false;
      if (mounted) {
        setState(() => _listenState = _ListenState.idle);
      }
      if (_continuousListening && !_manualStop) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        _scheduleRestart();
      }
    }
  }

  bool _looksLikeLocalCommand(String text) {
    final localWords = [
      'whatsapp',
      'youtube',
      'chrome',
      'camera',
      'calculator',
      'battery',
      'time',
      'weather',
      'kholo',
      'open',
      'chalao',
      'khol',
      'message bhejo',
      'whatsapp par',
    ];
    return localWords.any(text.contains);
  }

  Future<void> _executeCommand(String command) async {
    final lower = _normalize(command);

    if (_isWhatsAppMessageCommand(lower)) {
      final parsed = _parseWhatsAppMessage(lower);
      if (parsed != null) {
        await _handleWhatsAppContact(parsed.$1, parsed.$2);
      } else {
        await _respond('Sir, please say the contact name and message, for example: Dibaka ko WhatsApp message bhejo ghar aa jao.');
      }
      return;
    }

    if (_hasAny(lower, ['whatsapp open', 'open whatsapp', 'whatsapp'])) {
      final ok = await AndroidNativeBridge.openWhatsApp();
      await _respond(ok ? 'Opening WhatsApp, sir.' : 'Sir, WhatsApp is not installed or could not be opened.');
      return;
    }

    if (_hasAny(lower, ['youtube open', 'open youtube'])) {
      final ok = await AndroidNativeBridge.openAppPackage('com.google.android.youtube');
      await _respond(ok ? 'Opening YouTube.' : 'Sir, YouTube is not installed.');
      return;
    }

    if (_hasAny(lower, ['chrome open', 'open chrome'])) {
      final ok = await AndroidNativeBridge.openAppPackage('com.android.chrome');
      await _respond(ok ? 'Opening Chrome.' : 'Sir, Chrome is not installed.');
      return;
    }

    if (_hasAny(lower, ['camera open', 'open camera'])) {
      final ok = await AndroidNativeBridge.openCamera();
      await _respond(ok ? 'Opening Camera.' : 'Sir, I could not open the camera.');
      return;
    }

    if (_hasAny(lower, ['calculator open', 'open calculator'])) {
      final ok = await AndroidNativeBridge.openAppPackage('com.google.android.calculator');
      final fallback = ok ? true : await AndroidNativeBridge.openAppPackage('com.android.calculator2');
      await _respond(fallback ? 'Opening Calculator.' : 'Sir, I could not find a calculator app.');
      return;
    }

    if (_hasAny(lower, ['battery', 'battery batao', 'battery status'])) {
      await _respond('Sir, battery is $_batteryLevel percent and ${_isCharging ? 'currently charging' : 'not charging'}.');
      return;
    }

    if (_hasAny(lower, ['network', 'internet', 'wifi', 'connectivity'])) {
      await _respond('Sir, network status is $_networkStatus.');
      return;
    }

    if (_hasAny(lower, ['time', 'what time'])) {
      await _respond('Sir, the current device time is ${DateFormat('hh:mm a').format(DateTime.now())}.');
      return;
    }

    if (_hasAny(lower, ['weather', 'mausam'])) {
      await _fetchWeather('Bhadrak');
      return;
    }

    // Try an installed application by spoken name before Gemini.
    final appOpened = await AndroidNativeBridge.openAppByName(_extractOpenAppName(lower));
    if (appOpened) {
      await _respond('Opening ${_extractOpenAppName(lower)}.');
      return;
    }

    await _callGeminiApi(command);
  }

  bool _isWhatsAppMessageCommand(String text) {
    return text.contains('whatsapp') &&
        (text.contains('message bhejo') || text.contains('message send') || text.contains('whatsapp par'));
  }

  (String, String)? _parseWhatsAppMessage(String text) {
    var value = text.replaceFirst(RegExp(r'^whatsapp\s+par\s+'), '');
    final patterns = [
      RegExp(r'^(.*?)\s+ko\s+whatsapp\s+message\s+bhejo\s+(.+)$'),
      RegExp(r'^(.*?)\s+ko\s+whatsapp\s+message\s+send\s+(.+)$'),
      RegExp(r'^(.*?)\s+ko\s+(.+?)\s+whatsapp\s+message\s+bhejo$'),
      RegExp(r'^(.*?)\s+ko\s+whatsapp\s+(.+)$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 2) {
        final name = match.group(1)!.trim();
        final message = match.group(2)!.trim();
        if (name.isNotEmpty && message.isNotEmpty && name != 'whatsapp') return (name, message);
      }
    }
    final fallback = RegExp(r'^(.*?)\s+ko\s+(.+?)\s+whatsapp\s+par\s+bhejo$').firstMatch(text);
    if (fallback != null) return (fallback.group(1)!.trim(), fallback.group(2)!.trim());
    return null;
  }

  Future<void> _handleWhatsAppContact(String contact, String message) async {
    final contactsPermission = await Permission.contacts.request();
    if (!contactsPermission.isGranted) {
      await _respond('Sir, I need Contacts permission to find $contact.');
      return;
    }
    final result = await AndroidNativeBridge.openWhatsAppForContact(contact, message);
    final status = result['status']?.toString() ?? 'error';
    if (status == 'opened') {
      await _respond('WhatsApp chat for $contact is ready with the message composed.');
    } else if (status == 'not_found') {
      await _respond('Sir, I could not find $contact in your contacts.');
    } else if (status == 'not_installed') {
      await _respond('Sir, WhatsApp is not installed.');
    } else {
      await _respond('Sir, I could not open the WhatsApp chat.');
    }
  }

  String _extractOpenAppName(String command) {
    final cleaned = command
        .replaceFirst(RegExp(r'^(open|launch|start|chalao|khol|kholo)\s+'), '')
        .replaceFirst(RegExp(r'\s+(open|launch|start|chalao|khol|kholo)$'), '')
        .trim();
    return cleaned;
  }

  bool _hasAny(String text, List<String> values) => values.any(text.contains);

  Future<void> _respond(String text) async {
    _addJarvisMessage(text);
    await _speak(text);
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    if (mounted) setState(() => _listenState = _ListenState.speaking);
    try {
      await _tts.stop();
      final completer = Completer<void>();
      _tts.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
      await _tts.setLanguage(_languageCode);
      await _tts.speak(text);
      await completer.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    } catch (_) {
      // TTS failures should never kill the command loop.
    } finally {
      if (mounted) setState(() => _listenState = _ListenState.idle);
    }
  }

  Future<void> _fetchWeather(String city) async {
    if (_weatherApiKey.isEmpty) {
      await _respond('Weather API key is missing. Add it in Settings.');
      return;
    }
    try {
      final url = Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?q=$city&units=metric&appid=$_weatherApiKey');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final temp = (data['main']['temp'] as num).round();
        final desc = data['weather'][0]['description'];
        await _respond('Current temperature in $city is $temp degrees Celsius with $desc.');
      } else {
        await _respond('Unable to fetch weather data right now.');
      }
    } catch (_) {
      await _respond('Weather service is unavailable.');
    }
  }

  Future<void> _callGeminiApi(String prompt) async {
    if (_geminiApiKey.isEmpty) {
      await _respond('Gemini API key is missing. Please add it in Settings.');
      return;
    }
    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=$_geminiApiKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {
                'text': 'You are JARVIS, a concise Android AI assistant. Answer in the same language as the user when practical. Do not claim to have performed an Android action unless the app actually performed it.'
              }
            ]
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt}
              ]
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        final text = candidates != null && candidates.isNotEmpty
            ? ((candidates.first['content']?['parts'] as List<dynamic>?)?.first['text']?.toString() ?? '')
            : '';
        await _respond(text.isEmpty ? 'I could not get a useful Gemini response.' : text);
      } else {
        await _respond('Gemini API returned an error. Please check the API key and network connection.');
      }
    } catch (_) {
      await _respond('Gemini connection failed. Please check the internet connection.');
    }
  }

  void _addJarvisMessage(String text) {
    if (!mounted) return;
    setState(() => _chatHistory.add(_message('jarvis', text)));
  }

  Future<void> _fetchInstalledApps() async {
    final apps = await AndroidNativeBridge.getInstalledApps();
    if (!mounted) return;
    setState(() => _installedApps = apps);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _speech.stop();
    } else if (state == AppLifecycleState.resumed && _continuousListening && !_commandInProgress) {
      _scheduleRestart();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restartTimer?.cancel();
    _batterySubscription?.cancel();
    _connectivitySubscription?.cancel();
    _speech.stop();
    _tts.stop();
    super.dispose();
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
        backgroundColor: const Color(0xFF0F172A),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('J.A.R.V.I.S.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.cyanAccent)),
            Text('ANDROID AI ASSISTANT', style: TextStyle(fontSize: 9, color: Colors.cyanAccent)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_languageCode == 'en-US' ? Icons.language : Icons.translate, color: Colors.cyanAccent),
            onPressed: () async {
              setState(() => _languageCode = _languageCode == 'en-US' ? 'hi-IN' : 'en-US');
              await _tts.setLanguage(_languageCode);
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'HUD'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Voice'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.apps), label: 'Apps'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHomeDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _listenState == _ListenState.listening ? _stopListening() : _startListening(),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _listenState == _ListenState.listening ? Colors.redAccent : Colors.cyanAccent, width: 3),
                        boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(.25), blurRadius: 24)],
                      ),
                      child: Icon(_listenState == _ListenState.listening ? Icons.mic : Icons.mic_none, size: 50, color: Colors.cyanAccent),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(_statusText, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Wake words: Hey Jarvis • Jarvis • Hi GPT • GPT', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _metricCard('BATTERY', '$_batteryLevel%', _isCharging ? 'Charging' : 'Not charging', Icons.battery_std),
              _metricCard('NETWORK', _networkStatus, 'Real device state', Icons.network_check),
              _metricCard('LISTENING', _continuousListening ? 'ON' : 'OFF', _statusText, Icons.mic),
              _metricCard('APPS', '${_installedApps.length}', 'Launchable apps', Icons.apps),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton('WhatsApp', () => _executeCommand('whatsapp open')),
              _actionButton('YouTube', () => _executeCommand('youtube open')),
              _actionButton('Chrome', () => _executeCommand('chrome open')),
              _actionButton('Camera', () => _executeCommand('camera open')),
              _actionButton('Calculator', () => _executeCommand('calculator open')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 9, color: Colors.cyanAccent))),
              Icon(icon, size: 15, color: Colors.cyanAccent),
            ]),
            const SizedBox(height: 4),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) => ElevatedButton(
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 11)),
      );

  Widget _buildVoiceScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _listenState == _ListenState.listening ? _stopListening : _startListening,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.cyanAccent, width: 3),
                boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(.3), blurRadius: 35)],
              ),
              child: Icon(_listenState == _ListenState.listening ? Icons.mic : Icons.mic_off, size: 65, color: Colors.cyanAccent),
            ),
          ),
          const SizedBox(height: 28),
          Text(_statusText, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text('"$_lastWords"', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('Continuous listening'),
            subtitle: const Text('Restarts listening after each command'),
            value: _continuousListening,
            onChanged: (value) {
              setState(() => _continuousListening = value);
              if (value) _startListening(); else _stopListening();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatScreen() {
    final controller = TextEditingController();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _chatHistory.length,
            itemBuilder: (_, index) {
              final msg = _chatHistory[index];
              final user = msg['sender'] == 'user';
              return Align(
                alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(msg['text']?.toString() ?? ''),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Row(
            children: [
              Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Ask JARVIS...'))),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.cyanAccent),
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    _handleUserCommand(text);
                    controller.clear();
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
    if (_installedApps.isEmpty) {
      return const Center(child: Text('No launchable apps found.'));
    }
    return RefreshIndicator(
      onRefresh: _fetchInstalledApps,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _installedApps.length,
        itemBuilder: (_, index) {
          final app = Map<String, dynamic>.from(_installedApps[index] as Map);
          return ListTile(
            title: Text(app['name']?.toString() ?? ''),
            subtitle: Text(app['packageName']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.cyanAccent),
              onPressed: () => AndroidNativeBridge.openAppPackage(app['packageName'].toString()),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsScreen() {
    final geminiController = TextEditingController(text: _geminiApiKey);
    final weatherController = TextEditingController(text: _weatherApiKey);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('API CONFIGURATION', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: geminiController, obscureText: true, decoration: const InputDecoration(labelText: 'Gemini API Key', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: weatherController, obscureText: true, decoration: const InputDecoration(labelText: 'OpenWeather API Key (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('gemini_api_key', geminiController.text.trim());
            await prefs.setString('weather_api_key', weatherController.text.trim());
            if (!mounted) return;
            setState(() {
              _geminiApiKey = geminiController.text.trim();
              _weatherApiKey = weatherController.text.trim();
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration saved.')));
          },
          child: const Text('SAVE CONFIGURATION'),
        ),
      ],
    );
  }
}
