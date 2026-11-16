import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/watson_config.dart';
import '../data/orders_repo.dart';
import '../data/product_repo.dart';
import '../models/product.dart';
import 'auth_service.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.options = const [],
    this.isFromWatson = false,
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime createdAt;
  final List<String> options;
  final bool isFromWatson;
}

class WatsonService {
  WatsonService._({http.Client? client}) : _client = client ?? http.Client();

  static final instance = WatsonService._();

  @visibleForTesting
  factory WatsonService.forTest({required http.Client client}) {
    return WatsonService._(client: client);
  }

  final http.Client _client;
  String? _sessionId;

  bool get isWatsonConfigured => WatsonConfig.isConfigured;

  ChatMessage welcomeMessage() {
    return ChatMessage(
      id: 'welcome_${DateTime.now().microsecondsSinceEpoch}',
      text:
          'Olá! Sou o Assistente Virtual da Delta Store (integrado ao IBM watsonx Assistant).\n\nComo posso ajudar você hoje?',
      isUser: false,
      createdAt: DateTime.now(),
      options: const [
        'Ver produtos',
        'Meus pedidos',
        'Cupom de desconto',
        'Frete e entrega',
      ],
      isFromWatson: isWatsonConfigured,
    );
  }

  void resetSession() {
    _sessionId = null;
  }

  Future<ChatMessage> sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      return welcomeMessage();
    }

    if (WatsonConfig.isConfigured) {
      try {
        return await _sendToWatson(clean);
      } catch (_) {
        return _localFallbackReply(clean, watsonUnavailable: true);
      }
    }

    return _localFallbackReply(clean);
  }

  Map<String, String> get _headers {
    final credentials = base64Encode(
      utf8.encode('apikey:${WatsonConfig.apiKey.trim()}'),
    );
    return {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<String> _ensureSession() async {
    if (_sessionId != null) return _sessionId!;

    final uri = Uri.parse(
      '${WatsonConfig.normalizedServiceUrl}/v2/assistants/'
      '${WatsonConfig.assistantId.trim()}/sessions'
      '?version=${WatsonConfig.apiVersion}',
    );

    final response = await _client
        .post(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha ao criar sessão Watson (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final id = body['session_id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Sessão Watson retornou vazia');
    }

    _sessionId = id;
    return id;
  }

  Future<ChatMessage> _sendToWatson(String text, {bool retry = true}) async {
    final sessionId = await _ensureSession();
    final uri = Uri.parse(
      '${WatsonConfig.normalizedServiceUrl}/v2/assistants/'
      '${WatsonConfig.assistantId.trim()}/sessions/$sessionId/message'
      '?version=${WatsonConfig.apiVersion}',
    );

    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'input': {
              'message_type': 'text',
              'text': text,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 404 && retry) {
      _sessionId = null;
      return _sendToWatson(text, retry: false);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Erro na API do Watson (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final output = (body['output'] as Map<String, dynamic>?) ?? const {};
    final generic = (output['generic'] as List?) ?? const [];

    final texts = <String>[];
    final options = <String>[];

    for (final rawBlock in generic) {
      if (rawBlock is! Map<String, dynamic>) continue;
      final type = rawBlock['response_type']?.toString();

      if (type == 'text') {
        final msg = rawBlock['text']?.toString().trim() ?? '';
        if (msg.isNotEmpty) texts.add(msg);
      } else if (type == 'option') {
        final title = rawBlock['title']?.toString().trim() ?? '';
        if (title.isNotEmpty) texts.add(title);

        final rawOpts = (rawBlock['options'] as List?) ?? const [];
        for (final opt in rawOpts) {
          if (opt is Map<String, dynamic>) {
            final label = opt['label']?.toString().trim() ?? '';
            if (label.isNotEmpty) options.add(label);
          }
        }
      } else if (type == 'suggestion') {
        final title = rawBlock['title']?.toString().trim() ?? '';
        if (title.isNotEmpty) texts.add(title);

        final rawSug = (rawBlock['suggestions'] as List?) ?? const [];
        for (final sug in rawSug) {
          if (sug is Map<String, dynamic>) {
            final label = sug['label']?.toString().trim() ?? '';
            if (label.isNotEmpty) options.add(label);
          }
        }
      }
    }

    final replyText = texts.isNotEmpty
        ? texts.join('\n\n')
        : 'Recebi sua mensagem, mas o assistente não retornou texto.';

    return ChatMessage(
      id: 'watson_${DateTime.now().microsecondsSinceEpoch}',
      text: replyText,
      isUser: false,
      createdAt: DateTime.now(),
      options: options,
      isFromWatson: true,
    );
  }

  Future<ChatMessage> _localFallbackReply(
    String text, {
    bool watsonUnavailable = false,
  }) async {
    final normalized = text.toLowerCase();
    final notice = watsonUnavailable
        ? '(Não foi possível conectar ao IBM Watson agora; respondendo em modo local.)\n\n'
        : '';

    String reply;
    List<String> options = const [];

    if (_matchesAny(normalized, ['oi', 'olá', 'ola', 'bom dia', 'boa tarde', 'boa noite', 'menu', 'ajuda'])) {
      reply =
          'Olá! Posso ajudar você a encontrar roupas na loja, consultar seus pedidos, tirar dúvidas sobre cupons, tamanhos e frete.';
      options = const [
        'Ver produtos',
        'Meus pedidos',
        'Cupom de desconto',
        'Frete e entrega',
      ];
    } else if (_matchesAny(normalized, ['produto', 'camiseta', 'blusa', 'calca', 'calça', 'colete', 'catalogo', 'catálogo', 'preço', 'preco', 'comprar'])) {
      reply = await _describeProducts();
      options = const ['Tamanhos disponíveis', 'Cupom de desconto', 'Frete e entrega'];
    } else if (_matchesAny(normalized, ['pedido', 'compra', 'rastreio', 'status', 'historico', 'histórico'])) {
      reply = await _describeOrders();
      options = const ['Ver produtos', 'Frete e entrega'];
    } else if (_matchesAny(normalized, ['cupom', 'desconto', 'promocao', 'promoção', '10off'])) {
      reply =
          'Para usar um cupom, vá até a aba Carrinho, digite o código no campo "Cupom de desconto" (por exemplo, 10OFF se ativo na loja) e toque em Aplicar.';
      options = const ['Ver produtos', 'Frete e entrega'];
    } else if (_matchesAny(normalized, ['frete', 'entrega', 'envio', 'prazo'])) {
      reply =
          'O frete na Delta E-commerce é Grátis! Você pode conferir o resumo antes de finalizar sua compra na aba Carrinho.';
      options = const ['Ver produtos', 'Meus pedidos'];
    } else if (_matchesAny(normalized, ['tamanho', 'medida', 'p ', 'm ', 'g '])) {
      reply =
          'Cada produto exibe os tamanhos disponíveis na tela de detalhes (por padrão P, M e G, ou conforme cadastrado na peça). Selecione o tamanho desejado antes de adicionar ao carrinho.';
      options = const ['Ver produtos', 'Cupom de desconto'];
    } else if (_matchesAny(normalized, ['conta', 'login', 'senha', 'perfil', 'cadastro'])) {
      reply =
          'Você pode entrar, criar uma conta, editar seu nome ou enviar um e-mail de redefinição de senha diretamente na aba Perfil.';
      options = const ['Meus pedidos', 'Ver produtos'];
    } else {
      reply =
          'Entendi sua dúvida sobre "$text". No momento estou operando com respostas locais da loja. Escolha um dos tópicos abaixo ou pergunte sobre produtos, pedidos, cupons, tamanhos ou frete.';
      options = const [
        'Ver produtos',
        'Meus pedidos',
        'Cupom de desconto',
        'Frete e entrega',
      ];
    }

    return ChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      text: '$notice$reply',
      isUser: false,
      createdAt: DateTime.now(),
      options: options,
      isFromWatson: false,
    );
  }

  Future<String> _describeProducts() async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final products = await ProductRepo.instance
            .streamAll(limit: 5)
            .first
            .timeout(const Duration(seconds: 3));
        if (products.isNotEmpty) {
          final lines = products
              .map((p) => '• ${p.title} (${brl(p.priceCents)})')
              .join('\n');
          return 'Aqui estão alguns produtos disponíveis no catálogo:\n$lines\n\n'
              'Na aba Home você pode filtrar por camisetas, blusas, calças e coletes.';
        }
      } catch (_) {
        // Segue para a resposta padrão caso o Firestore não esteja acessível.
      }
    }

    return 'Temos diversas peças nas categorias camisetas, blusas, calças e coletes. '
        'Use os filtros no topo da aba Home para explorar todo o catálogo.';
  }

  Future<String> _describeOrders() async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final uid = AuthService.instance.uid;
        if (uid == null) {
          return 'Você ainda não está conectado. Entre na sua conta pela aba Perfil para acompanhar seus pedidos.';
        }
        final orders = await OrdersRepo.instance
            .streamByUser(uid)
            .first
            .timeout(const Duration(seconds: 3));
        if (orders.isEmpty) {
          return 'Você ainda não tem pedidos registrados. Que tal escolher uma peça na aba Home?';
        }
        final latest = orders.first;
        return 'Encontrei ${orders.length} pedido(s) na sua conta.\n'
            'O mais recente (#${latest.id}) está com status "${_orderStatusLabel(latest.status)}" '
            'no valor total de R\$ ${latest.totalPrice.toStringAsFixed(2).replaceAll('.', ',')}.\n\n'
            'Veja todos os detalhes em Perfil > Histórico de compras.';
      } catch (_) {
        // Segue para a resposta padrão caso o Firestore não esteja acessível.
      }
    }

    return 'Você pode consultar o status de todos os seus pedidos em Perfil > Histórico de compras.';
  }

  String _orderStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Criado';
      case 2:
        return 'Pago';
      case 3:
        return 'Enviado';
      case 4:
        return 'Entregue';
      default:
        return 'Em processamento';
    }
  }

  bool _matchesAny(String source, List<String> keywords) {
    for (final k in keywords) {
      if (source.contains(k)) return true;
    }
    return false;
  }
}
