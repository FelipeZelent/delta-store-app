import 'package:flutter/material.dart';
import '../config/watson_config.dart';
import '../services/watson_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(WatsonService.instance.welcomeMessage());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? presetText]) async {
    final text = (presetText ?? _inputCtrl.text).trim();
    if (text.isEmpty || _sending) return;

    if (presetText == null) {
      _inputCtrl.clear();
    }

    setState(() {
      _messages.add(
        ChatMessage(
          id: 'user_${DateTime.now().microsecondsSinceEpoch}',
          text: text,
          isUser: true,
          createdAt: DateTime.now(),
        ),
      );
      _sending = true;
    });
    _scrollToBottom();

    final reply = await WatsonService.instance.sendMessage(text);
    if (!mounted) return;

    setState(() {
      _messages.add(reply);
      _sending = false;
    });
    _scrollToBottom();
  }

  void _resetChat() {
    WatsonService.instance.resetSession();
    setState(() {
      _messages
        ..clear()
        ..add(WatsonService.instance.welcomeMessage());
    });
  }

  void _openWatsonSettingsDialog() {
    final keyCtrl = TextEditingController(text: WatsonConfig.apiKey);
    final urlCtrl = TextEditingController(text: WatsonConfig.serviceUrl);
    final idCtrl = TextEditingController(text: WatsonConfig.assistantId);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Configurar IBM Watson'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No painel do watsonx Assistant, acesse Assistant settings > API details e cole os 3 campos abaixo:',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Cole sua API Key da IBM',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Service URL',
                  hintText: 'https://api.us-south.assistant.watson.cloud.ibm.com/...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Environment ID / Assistant ID',
                  hintText: 'Cole o ID do ambiente ou assistente',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              WatsonConfig.updateCredentials(
                apiKey: keyCtrl.text,
                serviceUrl: urlCtrl.text,
                assistantId: idCtrl.text,
              );
              Navigator.pop(dialogCtx);
              _resetChat();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    WatsonConfig.isConfigured
                        ? 'Credenciais salvas! IBM Watson pronto para testar.'
                        : 'Campos limpos. Chat usando modo local.',
                  ),
                ),
              );
            },
            child: const Text('Salvar e conectar'),
          ),
        ],
      ),
    ).whenComplete(() {
      keyCtrl.dispose();
      urlCtrl.dispose();
      idCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final configured = WatsonService.instance.isWatsonConfigured;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assistente Delta'),
            Text(
              configured
                  ? 'IBM watsonx Assistant • Online'
                  : 'IBM watsonx Assistant • Assistente Virtual',
              style: TextStyle(
                fontSize: 12,
                color: configured ? Colors.greenAccent : Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configurar credenciais IBM Watson',
            onPressed: _openWatsonSettingsDialog,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Reiniciar conversa',
            onPressed: _resetChat,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, index) {
                if (_sending && index == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1B1E),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Digitando...', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                return _MessageBubble(
                  message: msg,
                  onOptionTap: _sending ? null : _send,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141518),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: .1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Pergunte sobre produtos, pedidos, cupons...',
                        filled: true,
                        fillColor: const Color(0xFF1A1B1E),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                    ),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onOptionTap});

  final ChatMessage message;
  final ValueChanged<String>? onOptionTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? cs.primaryContainer : const Color(0xFF1A1B1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    message.isFromWatson ? Icons.cloud_done : Icons.smart_toy_outlined,
                    size: 14,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Assistente Delta • IA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message.text,
              style: TextStyle(
                height: 1.38,
                color: isUser ? cs.onPrimaryContainer : Colors.white,
              ),
            ),
            if (message.options.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.options.map((opt) {
                  return ActionChip(
                    label: Text(opt),
                    onPressed: onOptionTap == null ? null : () => onOptionTap!(opt),
                    backgroundColor: const Color(0xFF25262B),
                    side: BorderSide(color: cs.primary.withValues(alpha: .35)),
                    labelStyle: const TextStyle(fontSize: 12),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
