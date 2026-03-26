// customer/lib/screens/concierge/concierge_screen.dart
// Calls Supabase Edge Function — NOT Anthropic API directly
// This is the security fix for the web app's VITE_ANTHROPIC_API_KEY exposure

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import 'dart:convert';

class _Message {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  _Message({required this.content, required this.isUser, required this.timestamp});
}

class ConciergeScreen extends ConsumerStatefulWidget {
  const ConciergeScreen({super.key});

  @override
  ConsumerState<ConciergeScreen> createState() => _ConciergeScreenState();
}

class _ConciergeScreenState extends ConsumerState<ConciergeScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Message> _messages = [
    _Message(
      content: "Hello! I'm Pearl, your AI travel concierge for Sri Lanka. I can help you plan stays, find vehicles, discover events, and book the perfect Sri Lankan experience. What would you like to explore?",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];
  bool _isThinking = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isThinking) return;

    setState(() {
      _messages.add(_Message(content: text, isUser: true, timestamp: DateTime.now()));
      _isThinking = true;
    });
    _msgCtrl.clear();
    _scrollToBottom();

    try {
      final supabase = ref.read(supabaseProvider);

      // ── Call Supabase Edge Function (NOT Anthropic directly) ─────────────
      // This is the production-safe pattern — API key stored as Supabase secret
      final response = await supabase.functions.invoke(
        'ai-concierge',
        body: {
          'message': text,
          'history': _messages
              .where((m) => !_isThinking || m != _messages.last)
              .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.content})
              .toList(),
        },
      );

      if (response.status != 200) {
        throw Exception('Concierge unavailable (${response.status})');
      }

      final data = response.data as Map<String, dynamic>;
      final reply = data['response'] as String? ?? 'Sorry, I could not process that.';

      setState(() {
        _messages.add(_Message(content: reply, isUser: false, timestamp: DateTime.now()));
        _isThinking = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_Message(
          content: 'Sorry, I\'m having trouble connecting right now. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isThinking = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFFB8943F), size: 20),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pearl Concierge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('AI Travel Assistant', style: TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() {
              _messages.clear();
              _messages.add(_Message(
                content: "Hello! I'm Pearl. How can I help you explore Sri Lanka today?",
                isUser: false,
                timestamp: DateTime.now(),
              ));
            }),
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Suggestion chips ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  'Best beach stays 🏖️',
                  'Kandy day trip 🌿',
                  'Budget vehicles 🚗',
                  'Events this weekend 🎉',
                  'Whale watching 🐋',
                ].map((s) => GestureDetector(
                  onTap: () {
                    _msgCtrl.text = s.replaceAll(RegExp(r'[^\w\s]'), '').trim();
                    _send();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8943F).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFB8943F).withOpacity(0.3)),
                    ),
                    child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFFB8943F), fontWeight: FontWeight.w500)),
                  ),
                )).toList(),
              ),
            ),
          ),

          // ── Messages ─────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length && _isThinking) {
                  return const _ThinkingBubble();
                }
                return _MessageBubble(message: _messages[i]);
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Ask Pearl anything about Sri Lanka...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: CircleAvatar(
                    backgroundColor: _isThinking ? Colors.grey.shade300 : const Color(0xFFB8943F),
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _isThinking ? null : _send,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1A1A2E),
              child: const Icon(Icons.auto_awesome, color: Color(0xFFB8943F), size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFFB8943F) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFB8943F).withOpacity(0.2),
              child: const Icon(Icons.person, color: Color(0xFFB8943F), size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF1A1A2E),
            child: Icon(Icons.auto_awesome, color: Color(0xFFB8943F), size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 200),
                const SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 8, height: 8,
      decoration: const BoxDecoration(color: Color(0xFFB8943F), shape: BoxShape.circle),
    ),
  );
}
