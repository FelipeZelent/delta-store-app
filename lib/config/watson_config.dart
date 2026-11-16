/// Configurações de integração com o IBM watsonx Assistant (API REST v2).
///
/// Como obter as credenciais no painel da IBM Cloud:
/// 1. Acesse https://cloud.ibm.com e abra seu recurso do **watsonx Assistant**
///    (o plano Lite é gratuito e funciona mesmo após expirar créditos de estudante).
/// 2. Abra seu Assistente e vá em **Assistant settings** > **API details**.
/// 3. Copie os 3 valores abaixo:
///    - **API Key** -> `apiKey`
///    - **Service instance URL** -> `serviceUrl` (ex.: `https://api.us-south.assistant.watson.cloud.ibm.com/instances/...`)
///    - **Environment ID** (ou **Assistant ID** no modo clássico) -> `assistantId`
///
/// Você pode:
/// - Colar esses 3 valores direto na tela do chat no ícone de engrenagem;
/// - Passar via `--dart-define`:
///   `flutter run --dart-define=WATSON_API_KEY=... --dart-define=WATSON_SERVICE_URL=... --dart-define=WATSON_ASSISTANT_ID=...`
/// - Ou preencher os `defaultValue` abaixo localmente (evite commitar chaves).
class WatsonConfig {
  WatsonConfig._();

  static const String _envApiKey = String.fromEnvironment(
    'WATSON_API_KEY',
    defaultValue: '',
  );

  static const String _envServiceUrl = String.fromEnvironment(
    'WATSON_SERVICE_URL',
    defaultValue: '',
  );

  static const String _envAssistantId = String.fromEnvironment(
    'WATSON_ASSISTANT_ID',
    defaultValue: '',
  );

  static String _apiKey = _envApiKey;
  static String _serviceUrl = _envServiceUrl;
  static String _assistantId = _envAssistantId;

  static String get apiKey => _apiKey;
  static String get serviceUrl => _serviceUrl;
  static String get assistantId => _assistantId;

  static const String apiVersion = '2023-06-15';

  static void updateCredentials({
    required String apiKey,
    required String serviceUrl,
    required String assistantId,
  }) {
    _apiKey = apiKey.trim();
    _serviceUrl = serviceUrl.trim();
    _assistantId = assistantId.trim();
  }

  static String get normalizedServiceUrl {
    final trimmed = _serviceUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static bool get isConfigured =>
      _apiKey.trim().isNotEmpty &&
      normalizedServiceUrl.isNotEmpty &&
      _assistantId.trim().isNotEmpty;
}
