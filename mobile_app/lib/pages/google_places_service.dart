import 'package:dio/dio.dart';

class GooglePlacesService {
  final String apiKey = "AIzaSyDckfLquBJ8U4zT2MJLuXqXbHE-cGeEzTQ"; // Coloque a key que você gerou

  Future<List<dynamic>> searchAddress(String input) async {
    if (input.isEmpty) return [];

    // O endpoint de Autocomplete do Google
    final String url = 
      "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$apiKey&language=pt-BR&components=country:br";

    try {
      final response = await Dio().get(url);
      if (response.data['status'] == 'OK') {
        return response.data['predictions'];
      } else {
        print("Erro na API: ${response.data['error_message']}");
        return [];
      }
    } catch (e) {
      print("Erro na requisição: $e");
      return [];
    }
  }
}