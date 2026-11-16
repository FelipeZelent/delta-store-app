import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appstore/config/watson_config.dart';
import 'package:appstore/data/product_repo.dart';
import 'package:appstore/models/product.dart';
import 'package:appstore/screens/chat_page.dart';
import 'package:appstore/services/auth_service.dart';
import 'package:appstore/services/watson_service.dart';

void main() {
  test('Formatação brl e cálculo de centavos preservam decimais', () {
    expect(brl(4990), 'R\$ 49,90');

    const priceDouble = 49.90;
    const qty = 2;
    final totalCents = (priceDouble * qty * 100).round();
    expect(totalCents, 9980);
    expect(brl(totalCents), 'R\$ 99,80');
  });

  test('ProductRepo e AuthService funcionam sem Firebase em ambiente de teste',
      () async {
    expect(AuthService.instance.isFirebaseReady, isFalse);
    expect(AuthService.instance.uid, isNull);

    final products = await ProductRepo.instance.streamAll().first;
    expect(products, isEmpty);

    final camisetas =
        await ProductRepo.instance.streamByCategory('camisetas').first;
    expect(camisetas, isEmpty);
  });

  test('Product usa fallback de imagem válido e controla flag exists', () {
    const prod = Product(
      id: 'p1',
      title: 'Camiseta Delta',
      priceCents: 7990,
      images: [],
      sizes: ['P', 'M', 'G'],
      description: 'Algodão',
      categoryId: 'camisetas',
    );

    expect(prod.exists, isTrue);
    expect(prod.imageUrl, contains('placehold.co'));
  });

  test('WatsonService responde em modo local quando não configurado', () async {
    final service = WatsonService.instance;
    expect(service.isWatsonConfigured, isFalse);

    final reply = await service.sendMessage('Como funciona o frete?');
    expect(reply.isUser, isFalse);
    expect(reply.isFromWatson, isFalse);
    expect(reply.text.toLowerCase(), contains('grátis'));
  });

  test('WatsonConfig atualiza credenciais em runtime', () {
    WatsonConfig.updateCredentials(
      apiKey: '  chave-teste  ',
      serviceUrl: 'https://api.example.com/',
      assistantId: 'env-123',
    );
    expect(WatsonConfig.isConfigured, isTrue);
    expect(WatsonConfig.normalizedServiceUrl, 'https://api.example.com');

    WatsonConfig.updateCredentials(apiKey: '', serviceUrl: '', assistantId: '');
    expect(WatsonConfig.isConfigured, isFalse);
  });

  testWidgets('ChatPage renderiza boas-vindas e responde ao enviar mensagem',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatPage(),
      ),
    );

    expect(find.text('Assistente Delta'), findsOneWidget);
    expect(
      find.text('IBM watsonx Assistant • Assistente Virtual'),
      findsOneWidget,
    );
    expect(find.text('Ver produtos'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Qual o valor do frete?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Qual o valor do frete?'), findsOneWidget);
    expect(find.textContaining('Grátis'), findsOneWidget);
  });
}
