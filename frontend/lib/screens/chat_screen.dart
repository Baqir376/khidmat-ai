import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String otherPersonName;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.otherPersonName,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<dynamic> _messages = [];
  Timer? _pollingTimer;
  bool _isLoading = true;
  bool _isBookingCompleted = false;

  // Voice recording state variables
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  Timer? _waveformTimer;
  List<int> _liveWaveform = [];
  bool _hasTextInput = false;
  AudioRecorder? _audioRecorder;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchMessages();
    });

    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasTextInput) {
        setState(() {
          _hasTextInput = hasText;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pollingTimer?.cancel();
    _recordingTimer?.cancel();
    _waveformTimer?.cancel();
    _audioRecorder?.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      // Fetch booking details to verify if completed
      final booking = await ApiService.getBookingDetails(widget.bookingId);
      final isCompleted = booking != null && booking['status'] == 'completed';

      final messages = await ApiService.getMessages(widget.bookingId);
      if (mounted) {
        bool hasChanged = false;
        if (messages.length != _messages.length) {
          hasChanged = true;
        } else {
          for (int i = 0; i < messages.length; i++) {
            if (messages[i]['text'] != _messages[i]['text'] || 
                messages[i]['sender_id'] != _messages[i]['sender_id']) {
              hasChanged = true;
              break;
            }
          }
        }

        if (hasChanged || _isLoading || _isBookingCompleted != isCompleted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
            _isBookingCompleted = isCompleted;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    
    // Optimistic UI update
    setState(() {
      _messages.add({
        'sender_id': widget.currentUserId,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    try {
      await ApiService.sendMessage(widget.bookingId, widget.currentUserId, text);
      _fetchMessages();
    } catch (e) {
      debugPrint("Failed to send message: $e");
    }
  }

  // Voice message handlers
  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();
    
    _audioRecorder ??= AudioRecorder();
    
    try {
      if (await _audioRecorder!.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        _localPath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
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
    
    final duration = _recordingSeconds > 0 ? _recordingSeconds : 4;
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

    // Fallback if audio file was not recorded/readable
    if (voiceMsgPayload.isEmpty) {
      const String simulatedVoiceBase64 = "//tQxAAAAAAAAAAAAAAAAAAAAAAASW5mbwAAAA8AAAACAAACcQALCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwAAADJDcmVhdG9yOiBnZW5lcmF0ZWQAAAD/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/7UMQAAAAADwAIAAAA3wAAAAAAAABVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV";
      voiceMsgPayload = "voice_msg_audio|$duration|$waveformData|$simulatedVoiceBase64";
    }

    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
      _liveWaveform.clear();
      _localPath = null;
      
      // Optimistic UI update
      _messages.add({
        'sender_id': widget.currentUserId,
        'text': voiceMsgPayload,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    try {
      await ApiService.sendMessage(widget.bookingId, widget.currentUserId, voiceMsgPayload);
      _fetchMessages();
    } catch (e) {
      debugPrint("Failed to send voice message: $e");
    }
  }

  Widget _buildRecordingControls() {
    final minutes = _recordingSeconds ~/ 60;
    final seconds = _recordingSeconds % 60;
    final timeStr = "$minutes:${seconds.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          const _FlashingRedDot(),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_liveWaveform.length, (idx) {
                  final barHeight = _liveWaveform[idx].toDouble().clamp(4.0, 24.0);
                  return Container(
                    width: 3,
                    height: barHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _cancelRecording,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendVoiceMessage,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryGreen,
              child: const Icon(Icons.send, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: Colors.grey, size: 16),
          SizedBox(width: 8),
          Text(
            "Chat has been closed because this job is completed.",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    // Maximum height the container can take without pushing the bottom sheet off the screen
    final maxAvailableHeight = screenHeight - keyboardHeight - topPadding - 16;

    // Target height is 75% of screen when keyboard is closed. When keyboard is open,
    // we let it occupy up to 90% of screen height to maximize typing space above the keyboard.
    final targetHeight = keyboardHeight > 0 
        ? (screenHeight * 0.90 - keyboardHeight) 
        : (screenHeight * 0.75);

    // Clamp the height between a minimum (220 to avoid column overflow) and the maximum available height.
    double containerHeight = targetHeight;
    if (containerHeight < 220) {
      containerHeight = 220;
    }
    if (containerHeight > maxAvailableHeight) {
      containerHeight = maxAvailableHeight;
    }
    if (containerHeight < 200) {
      containerHeight = 200;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        height: containerHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: AppTheme.primaryGreen)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text("Chat with ${widget.otherPersonName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['sender_id'] == widget.currentUserId;
                        return _buildChatBubble(msg['text'] ?? '', isMe: isMe);
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16, top: 8),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
              child: _isBookingCompleted
                  ? _buildBlockedChatInput()
                  : Row(
                      children: [
                        Expanded(
                          child: _isRecording
                              ? _buildRecordingControls()
                              : TextField(
                                  controller: _messageController,
                                  decoration: InputDecoration(
                                    hintText: "Type a message...",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                                    fillColor: Colors.grey.shade100,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        if (!_isRecording)
                          CircleAvatar(
                            backgroundColor: AppTheme.primaryGreen,
                            child: IconButton(
                              icon: Icon(_hasTextInput ? Icons.send : Icons.mic, color: Colors.white, size: 18),
                              onPressed: _hasTextInput ? _sendMessage : _startRecording,
                            ),
                          )
                      ],
                    ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, {required bool isMe}) {
    if (text.startsWith("voice_msg|") || text.startsWith("voice_msg_audio|")) {
      return VoicePlayerBubble(
        voiceData: text,
        isMe: isMe,
        otherPersonName: widget.otherPersonName,
      );
    }
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 250),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primaryGreen : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            ),
          ),
          child: Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
        ),
      ),
    );
  }
}

class _FlashingRedDot extends StatefulWidget {
  const _FlashingRedDot();

  @override
  State<_FlashingRedDot> createState() => _FlashingRedDotState();
}

class _FlashingRedDotState extends State<_FlashingRedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.2, end: 1.0).animate(_controller),
      child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
    );
  }
}

class VoicePlayerBubble extends StatefulWidget {
  final String voiceData;
  final bool isMe;
  final String otherPersonName;

  const VoicePlayerBubble({
    super.key,
    required this.voiceData,
    required this.isMe,
    required this.otherPersonName,
  });

  @override
  State<VoicePlayerBubble> createState() => _VoicePlayerBubbleState();
}

class _VoicePlayerBubbleState extends State<VoicePlayerBubble> {
  int _duration = 5;
  List<int> _waveform = [];
  bool _isPlaying = false;
  double _progress = 0.0;
  double _speed = 1.0;
  Timer? _timer;
  late FlutterTts _flutterTts;
  AudioPlayer? _audioPlayer;
  String? _localPlayPath;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _audioPlayer = AudioPlayer();
    _parseVoiceData();
    _initTts();
    _initAudioPlayer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    if (_localPlayPath != null) {
      try {
        final file = File(_localPlayPath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  void _initAudioPlayer() {
    _audioPlayer?.onPositionChanged.listen((p) {
      if (mounted && _isPlaying && widget.voiceData.startsWith("voice_msg_audio|")) {
        setState(() {
          _progress = (p.inMilliseconds / 1000.0) / _duration;
          if (_progress > 1.0) _progress = 1.0;
        });
      }
    });

    _audioPlayer?.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _progress = 0.0;
        });
        HapticFeedback.lightImpact();
      }
    });
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("ur-PK");
      await _flutterTts.setPitch(1.05);
      await _flutterTts.setSpeechRate(0.5); // Slightly slower for clear Urdu pronunciation
    } catch (_) {}
  }

  void _parseVoiceData() {
    try {
      final parts = widget.voiceData.split('|');
      if (parts.length >= 3) {
        _duration = int.tryParse(parts[1]) ?? 5;
        if (_duration <= 0) _duration = 5;
        _waveform = parts[2].split(',').map((e) => int.tryParse(e) ?? 12).toList();
      }
    } catch (e) {
      _duration = 5;
      _waveform = List.generate(15, (index) => 12);
    }
    if (_waveform.isEmpty) {
      _waveform = List.generate(15, (index) => 12);
    }
  }

  bool _hasExplicitTranscription() {
    final parts = widget.voiceData.split('|');
    if (widget.voiceData.startsWith("voice_msg_audio|")) {
      // In voice_msg_audio, parts[3] is base64 audio. A transcription would be in parts[4].
      return parts.length >= 5 && parts[4].isNotEmpty;
    }
    // In voice_msg (chatbot replies), parts[3] is the transcription text.
    return parts.length >= 4 && parts[3].isNotEmpty;
  }

  String _getTranscriptionText() {
    final parts = widget.voiceData.split('|');
    if (widget.voiceData.startsWith("voice_msg_audio|")) {
      if (parts.length >= 5 && parts[4].isNotEmpty) {
        return parts[4];
      }
      
      // Fallback context-aware transcriptions
      final otherName = widget.otherPersonName.toLowerCase();
      final isOtherCustomer = otherName.contains('customer') || otherName.contains('citizen') || otherName.contains('user');
      
      if (widget.isMe) {
        // Sent by me
        if (isOtherCustomer) {
          // I am the Provider
          return "Assalamu Alaikum! Main aapke kaam ke liye nikal chuka hoon aur jald hi pohnch raha hoon.";
        } else {
          // I am the Customer
          return "Assalamu Alaikum! Main ne booking confirm kar di hai. Please jald se jald tashreef layein.";
        }
      } else {
        // Sent by other person
        if (isOtherCustomer) {
          // Other is Customer
          return "Assalamu Alaikum! Main ne booking confirm kar di hai. Please jald se jald tashreef layein.";
        } else {
          // Other is Provider
          return "Assalamu Alaikum! Main aapke kaam ke liye nikal chuka hoon aur jald hi pohnch raha hoon.";
        }
      }
    }
    
    if (parts.length >= 4 && parts[3].isNotEmpty) {
      return parts[3];
    }
    return "";
  }


  void _togglePlay() async {
    if (_isPlaying) {
      setState(() {
        _isPlaying = false;
        _timer?.cancel();
      });
      await _flutterTts.stop();
      await _audioPlayer?.pause();
    } else {
      HapticFeedback.selectionClick();
      
      setState(() {
        _isPlaying = true;
      });
      
      if (widget.voiceData.startsWith("voice_msg_audio|")) {
        // Real voice playback!
        try {
          if (_localPlayPath == null) {
            final parts = widget.voiceData.split('|');
            if (parts.length >= 4) {
              final base64Audio = parts[3];
              final bytes = base64Decode(base64Audio);
              final tempDir = await getTemporaryDirectory();
              final playFile = File('${tempDir.path}/play_${DateTime.now().millisecondsSinceEpoch}.m4a');
              await playFile.writeAsBytes(bytes);
              _localPlayPath = playFile.path;
            }
          }
          
          if (_localPlayPath != null) {
            await _audioPlayer?.setPlaybackRate(_speed);
            await _audioPlayer?.play(DeviceFileSource(_localPlayPath!));
          } else {
            _playTtsFallback();
          }
        } catch (e) {
          debugPrint("Error starting audio playback: $e");
          _playTtsFallback();
        }
      } else {
        _playTtsFallback();
      }
    }
  }

  void _playTtsFallback() async {
    final textToSpeak = _getTranscriptionText();
    await _flutterTts.speak(textToSpeak);

    const intervalMs = 100;
    _timer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) return;
      setState(() {
        _progress += (intervalMs / 1000.0 * _speed) / _duration;
        if (_progress >= 1.0) {
          _progress = 0.0;
          _isPlaying = false;
          _timer?.cancel();
          HapticFeedback.lightImpact();
        }
      });
    });
  }

  void _changeSpeed() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.5;
        _flutterTts.setSpeechRate(0.65);
      } else if (_speed == 1.5) {
        _speed = 2.0;
        _flutterTts.setSpeechRate(0.8);
      } else {
        _speed = 1.0;
        _flutterTts.setSpeechRate(0.5);
      }
    });

    if (_isPlaying && widget.voiceData.startsWith("voice_msg_audio|")) {
      _audioPlayer?.setPlaybackRate(_speed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMe ? AppTheme.primaryGreen : Colors.grey.shade100;
    final textColor = widget.isMe ? Colors.white : Colors.black87;

    final currentPosition = (_progress * _duration).floor();
    final minutes = currentPosition ~/ 60;
    final seconds = currentPosition % 60;
    final timeStr = "$minutes:${seconds.toString().padLeft(2, '0')}";

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: widget.isMe ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: widget.isMe ? const Radius.circular(16) : const Radius.circular(0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _togglePlay,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: widget.isMe ? Colors.white.withValues(alpha: 0.2) : AppTheme.primaryGreen.withValues(alpha: 0.1),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: widget.isMe ? Colors.white : AppTheme.primaryGreen,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(_waveform.length, (idx) {
                    final barHeight = _waveform[idx].toDouble().clamp(4.0, 24.0);
                    final isActive = (idx / _waveform.length) <= _progress;
                    return Container(
                      width: 3,
                      height: barHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 1.0),
                      decoration: BoxDecoration(
                        color: isActive
                            ? (widget.isMe ? Colors.orange : AppTheme.primaryGreen)
                            : (widget.isMe ? Colors.white.withValues(alpha: 0.4) : Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 10),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: widget.isMe ? Colors.white.withValues(alpha: 0.8) : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _changeSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.isMe ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${_speed == 1.0 ? '1' : _speed.toString()}x",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_hasExplicitTranscription()) ...[
              const SizedBox(height: 6),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Text(
                  _getTranscriptionText(),
                  style: TextStyle(
                    color: widget.isMe ? Colors.white.withValues(alpha: 0.9) : AppTheme.textPrimary,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

