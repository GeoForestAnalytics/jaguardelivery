/// OneSignal — crie sua conta em onesignal.com e substitua o App ID abaixo
class OneSignalConfig {
  /// App ID encontrado em: OneSignal Dashboard → Settings → Keys & IDs
  static const appId = 'a1641d66-6700-46fc-9f66-cf5f1e2c5fb5';
}

/// Configurações da Evolution API (WhatsApp)
class EvolutionConfig {
  static const baseUrl = 'https://SEU_EVOLUTION_URL';
  static const apiKey  = 'SUA_CHAVE_AQUI';
  static String instanceName(String userId) =>
      'jaguar_${userId.replaceAll('-', '').substring(0, 12)}';
}

/// Configurações do Google Places API
class GoogleConfig {
  static const placesApiKey = 'AIzaSyDckfLquBJ8U4zT2MJLuXqXbHE-cGeEzTQ';
}
