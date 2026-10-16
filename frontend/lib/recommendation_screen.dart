import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  _RecommendationScreenState createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _recommendations = [];
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> fetchRecommendations(String perfumeName) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _recommendations = [];
    });

    final String apiUrl = 'https://find-ur-scent.onrender.com/recommend';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': perfumeName}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recommendations = data['recommendations'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'API Error (Status ${response.statusCode}): ရေမွှေးရှာမတွေ့ပါ။';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        // Error အတိအကျကို မျက်နှာပြင်တွင် ဖော်ပြပေးမည်
        _errorMessage = 'အမှားအယွင်း: $e'; 
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find ur scent - AI Recommendations'),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ရေမွှေးအမည် ရိုက်ထည့်ပါ (ဥပမာ - versace eros)',
                labelStyle: const TextStyle(color: Colors.white70),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD4AF37)),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      fetchRecommendations(_searchController.text);
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) fetchRecommendations(value);
              },
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(color: Color(0xFFD4AF37)),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage, 
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _recommendations.length,
                itemBuilder: (context, index) {
                  final perfume = _recommendations[index];
                  return Card(
                    color: Colors.white.withValues(alpha: 0.08),
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            perfume['Perfume']?.toString().toUpperCase() ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD4AF37),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Brand: ${perfume['Brand'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 14, fontStyle: FontStyle.italic, color: Colors.white70),
                          ),
                          const Divider(color: Colors.white24, height: 24),
                          Text('Top Notes: ${perfume['Top'] ?? ''}', style: const TextStyle(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Middle Notes: ${perfume['Middle'] ?? ''}', style: const TextStyle(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Base Notes: ${perfume['Base'] ?? ''}', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}