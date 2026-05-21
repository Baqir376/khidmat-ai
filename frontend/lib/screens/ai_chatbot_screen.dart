import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../providers/app_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';
import 'chat_screen.dart';

class AIChatbotScreen extends StatefulWidget {
  final double userLat;
  final double userLng;

  const AIChatbotScreen({
    super.key,
    required this.userLat,
    required this.userLng,
  });

  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  
  bool _isSending = false;
  bool _hasTextInput = false;

  // Voice recording state
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  Timer? _waveformTimer;
  List<int> _liveWaveform = [];
  AudioRecorder? _audioRecorder;
  String? _localPath;

  // TTS for reading messages
  final FlutterTts _flutterTts = FlutterTts();
  String? _currentlySpeakingId;

  @override
  void initState() {
    super.initState();
    _initTts();
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasTextInput) {
        setState(() {
          _hasTextInput = hasText;
        });
      }
    });

    // Add initial greeting after frame render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = context.read<LanguageProvider>();
      setState(() {
        _messages.add({
          'id': 'greeting',
          'sender': 'assistant',
          'text': lang.isUrdu ? AppStrings.chatGreeting_ur : AppStrings.chatGreeting_en,
          'timestamp': DateTime.now(),
        });
      });
    });
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _currentlySpeakingId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _waveformTimer?.cancel();
    _audioRecorder?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();
    _audioRecorder ??= AudioRecorder();
    
    try {
      if (await _audioRecorder!.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        _localPath = '${tempDir.path}/ai_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder!.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), 
          path: _localPath!,
        );
        
        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
          _liveWaveform = [8, 12, 10, 16, 22, 15];
        });

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingSeconds++;
            });
          }
        });

        _waveformTimer?.cancel();
        _waveformTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
          if (mounted && _isRecording) {
            setState(() {
              final baseVal = (DateTime.now().millisecond % 28) + 6;
              _liveWaveform.add(baseVal);
              if (_liveWaveform.length > 22) {
                _liveWaveform.removeAt(0);
              }
            });
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required to send voice messages.'))
          );
        }
      }
    } catch (e) {
      debugPrint("Error starting audio recording: $e");
    }
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.lightImpact();
    _recordingTimer?.cancel();
    _waveformTimer?.cancel();
    
    try {
      await _audioRecorder?.stop();
      if (_localPath != null) {
        final file = File(_localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint("Error canceling voice message: $e");
    }
    
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
      _liveWaveform.clear();
      _localPath = null;
    });
  }

  Future<void> _sendVoiceMessage() async {
    HapticFeedback.mediumImpact();
    _recordingTimer?.cancel();
    _waveformTimer?.cancel();
    
    String? audioPath;
    try {
      audioPath = await _audioRecorder?.stop();
    } catch (e) {
      debugPrint("Error stopping audio recorder: $e");
    }
    
    final duration = _recordingSeconds > 0 ? _recordingSeconds : 3;
    final waveformData = _liveWaveform.isNotEmpty ? _liveWaveform.join(',') : '8,15,22,12,18,6';
    
    String voiceMsgPayload = "";
    
    if (audioPath != null && _localPath != null) {
      try {
        final file = File(_localPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64Audio = base64Encode(bytes);
          voiceMsgPayload = "voice_msg_audio|$duration|$waveformData|$base64Audio";
        }
      } catch (e) {
        debugPrint("Error reading audio file: $e");
      }
    }

    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
      _liveWaveform.clear();
      _localPath = null;
    });

    if (voiceMsgPayload.isNotEmpty) {
      await _sendMessageToServer(voiceMsgPayload, isVoice: true);
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    await _sendMessageToServer(text);
  }

  Future<void> _sendMessageToServer(String text, {bool isVoice = false}) async {
    final langProvider = context.read<LanguageProvider>();
    final appProvider = context.read<AppProvider>();

    final userMessageMap = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender': 'user',
      'text': text,
      'timestamp': DateTime.now(),
    };

    setState(() {
      _messages.add(userMessageMap);
      _isSending = true;
    });
    
    Timer(const Duration(milliseconds: 100), _scrollToBottom);

    try {
      // Build history for endpoint, using transcription when available so we don't send huge base64 blocks
      final List<Map<String, String>> chatHistory = _messages
          .where((m) => m['id'] != 'greeting' && m['id'] != userMessageMap['id'])
          .map<Map<String, String>>((m) {
            String msgText = m['text'].toString();
            if (msgText.startsWith("voice_msg_audio|")) {
              if (m['transcription'] != null && m['transcription'].toString().isNotEmpty) {
                msgText = m['transcription'].toString();
              } else {
                msgText = "Sent a voice message";
              }
            } else if (msgText.startsWith("voice_msg|")) {
              final parts = msgText.split('|');
              if (parts.length >= 4) {
                msgText = parts[3];
              }
            }
            return {
              'role': m['sender'] == 'user' ? 'user' : 'assistant',
              'text': msgText,
            };
          })
          .toList();

      final res = await ApiService.sendAIChat(
        message: text,
        history: chatHistory,
        lat: widget.userLat,
        lng: widget.userLng,
        language: langProvider.languageCode,
      );

      final reply = res['reply'] ?? '';
      final action = res['action'] ?? 'chat';
      final serviceType = res['service_type'];
      final userTrans = res['user_transcription'] as String?;

      if (mounted) {
        setState(() {
          if (userTrans != null && userTrans.isNotEmpty) {
            userMessageMap['transcription'] = userTrans;
          }
          _messages.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'sender': 'assistant',
            'text': "voice_msg|${(reply.length / 15).clamp(3, 15).toInt()}|12,18,22,14,16,10,15,8,12,6|$reply",
            'timestamp': DateTime.now(),
          });
          _isSending = false;
        });
        Timer(const Duration(milliseconds: 100), _scrollToBottom);

        // Dynamic TTS Reading (Auto-speak disabled)
        // _speak(reply);

        // Check if redirect required
        if (action == 'show_providers' && serviceType != null) {
          final redirectQuery = res['redirect_query'] ?? "$serviceType service needed";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(langProvider.isUrdu 
                  ? "🔍 سروس تلاش کی جا رہی ہے..." 
                  : "🔍 Finding providers for you..."),
              backgroundColor: AppTheme.primaryGreen,
              duration: const Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(seconds: 2));

          if (mounted) {
            setState(() => _isSending = true);
            await appProvider.submitRequest(
              redirectQuery,
              lat: widget.userLat,
              lng: widget.userLng,
            );
            if (mounted) {
              setState(() => _isSending = false);
              if (appProvider.error == null) {
                Navigator.pushNamed(context, '/booking');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(appProvider.error!),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'sender': 'assistant',
            'text': langProvider.isUrdu ? AppStrings.error_ur : AppStrings.error_en,
            'timestamp': DateTime.now(),
          });
          _isSending = false;
        });
        Timer(const Duration(milliseconds: 100), _scrollToBottom);
      }
    }
  }

  Future<void> _speak(String text) async {
    final lang = context.read<LanguageProvider>();
    if (lang.isUrdu) {
      // If Urdu is spoken, set appropriate TTS language
      await _flutterTts.setLanguage("ur-PK");
    } else {
      await _flutterTts.setLanguage("en-US");
    }
    
    // Stop if currently speaking
    await _flutterTts.stop();
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _currentlySpeakingId = id;
    });

    // Clean formatting brackets before speaking
    final cleanText = text.replaceAll(RegExp(r'\[.*?\]'), '');
    await _flutterTts.speak(cleanText);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _currentlySpeakingId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.t(AppStrings.chatTitle_en, AppStrings.chatTitle_ur),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              lang.t(AppStrings.chatSubtitle_en, AppStrings.chatSubtitle_ur),
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_off),
            onPressed: _stopSpeaking,
            tooltip: 'Stop AI voice output',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m['sender'] == 'user';
                return _buildMessageBubble(m, isUser);
              },
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
              ),
            ),
          _buildInputBar(lang),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isUser) {
    final text = message['text'] as String;
    final isGreeting = message['id'] == 'greeting';

    if (text.startsWith("voice_msg|") || text.startsWith("voice_msg_audio|")) {
      String displayVoiceData = text;
      final trans = message['transcription'] as String?;
      if (text.startsWith("voice_msg_audio|") && trans != null && trans.isNotEmpty) {
        // Appending the transcription as parts[4]
        displayVoiceData = "$text|$trans";
      }
      return VoicePlayerBubble(
        voiceData: displayVoiceData,
        isMe: isUser,
        otherPersonName: "AI Chatbot",
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.primaryGreen
              : (isGreeting ? Colors.blue.shade50 : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isUser 
                    ? Colors.white 
                    : (isGreeting ? Colors.blue.shade900 : AppTheme.textPrimary),
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _speak(text),
                    child: Icon(
                      Icons.volume_up,
                      size: 16,
                      color: _currentlySpeakingId != null 
                          ? AppTheme.primaryGreen 
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(LanguageProvider lang) {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        color: Colors.white,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _cancelRecording,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'Recording: ${_recordingSeconds}s',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  // Animated waveform visualization
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _liveWaveform.map((val) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 3.5,
                            height: val.toDouble(),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: AppTheme.primaryGreen),
              onPressed: _sendVoiceMessage,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onLongPress: _startRecording,
              child: IconButton(
                icon: const Icon(Icons.mic, color: AppTheme.primaryGreen),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Press and hold mic to record audio message."),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: lang.t(AppStrings.chatHint_en, AppStrings.chatHint_ur),
                    border: InputBorder.none,
                    hintStyle: const TextStyle(color: Colors.grey),
                  ),
                  maxLines: null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _hasTextInput ? AppTheme.primaryGreen : Colors.grey.shade300,
              child: IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.white),
                onPressed: _hasTextInput ? _sendTextMessage : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
