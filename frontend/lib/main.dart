import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FindUrScentApp());
}

class ApiConfig {
  static const String baseUrl = 'https://find-ur-scent.onrender.com';
}

class FindUrScentApp extends StatelessWidget {
  const FindUrScentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Find ur scent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
          secondary: Color(0xFFE5C158),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> savedWardrobe = [];
  List<Map<String, dynamic>> sotdLogs = [];

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final wardrobeStr = prefs.getString('wardrobe');
    final logsStr = prefs.getString('sotd_logs');
    setState(() {
      if (wardrobeStr != null) {
        savedWardrobe = List<Map<String, dynamic>>.from(jsonDecode(wardrobeStr));
      }
      if (logsStr != null) {
        sotdLogs = List<Map<String, dynamic>>.from(jsonDecode(logsStr));
      }
    });
  }

  Future<void> _toggleWardrobe(Map<String, dynamic> perfume) async {
    final prefs = await SharedPreferences.getInstance();
    final exists = savedWardrobe.any((p) => p['id'] == perfume['id']);
    setState(() {
      if (exists) {
        savedWardrobe.removeWhere((p) => p['id'] == perfume['id']);
      } else {
        savedWardrobe.add(perfume);
      }
    });
    await prefs.setString('wardrobe', jsonEncode(savedWardrobe));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exists ? 'Wardrobe ထဲမှ ဖယ်ရှားလိုက်ပါပြီ' : '${perfume['name']} ကို Wardrobe ထဲ သိမ်းဆည်းပြီးပါပြီ ❤️'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _logScentOfTheDay(Map<String, dynamic> perfume) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year} (${now.hour}:${now.minute.toString().padLeft(2, '0')})';
    final logEntry = {
      'name': perfume['name'],
      'brand': perfume['brand'],
      'date': dateStr,
    };
    setState(() {
      sotdLogs.insert(0, logEntry);
    });
    await prefs.setString('sotd_logs', jsonEncode(sotdLogs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✨ ဒီနေ့ဆွတ်သည့်ရေမွှေး (${perfume['name']}) ကို မှတ်တမ်းတင်ပြီးပါပြီ!')),
      );
    }
  }

  bool _isSaved(int id) => savedWardrobe.any((p) => p['id'] == id);

  @override
  Widget build(BuildContext context) {
    final pages = [
      ScentQuizTab(
        onToggleSave: _toggleWardrobe,
        onLogSotd: _logScentOfTheDay,
        isSaved: _isSaved,
      ),
      ExplorePerfumesTab(
        onToggleSave: _toggleWardrobe,
        onLogSotd: _logScentOfTheDay,
        isSaved: _isSaved,
      ),
      WardrobeTab(
        wardrobe: savedWardrobe,
        sotdLogs: sotdLogs,
        onRemove: _toggleWardrobe,
        onLogSotd: _logScentOfTheDay,
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFF2A1F3D), Color(0xFF0D0D12)],
          ),
        ),
        child: SafeArea(child: pages[_currentIndex]),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF14141D),
        indicatorColor: const Color(0xFFD4AF37).withValues(alpha: 0.25),
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome, color: Color(0xFFD4AF37)),
            label: 'AI Quiz',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.manage_search, color: Color(0xFFD4AF37)),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: savedWardrobe.isNotEmpty,
              label: Text('${savedWardrobe.length}'),
              child: const Icon(Icons.favorite_border),
            ),
            selectedIcon: const Icon(Icons.favorite, color: Color(0xFFD4AF37)),
            label: 'My Wardrobe',
          ),
        ],
      ),
    );
  }
}

// ==================== TAB 1: AI SCENT QUIZ ====================
class ScentQuizTab extends StatefulWidget {
  final Function(Map<String, dynamic>) onToggleSave;
  final Function(Map<String, dynamic>) onLogSotd;
  final bool Function(int) isSaved;

  const ScentQuizTab({super.key, required this.onToggleSave, required this.onLogSotd, required this.isSaved});

  @override
  State<ScentQuizTab> createState() => _ScentQuizTabState();
}

class _ScentQuizTabState extends State<ScentQuizTab> {
  String selectedSeason = 'hot_humid';
  String selectedOccasion = 'daily_uni';
  String selectedVibe = 'fresh_clean';
  final List<String> selectedNotes = ['citrus', 'aquatic'];
  bool isLoading = false;
  List<dynamic> recommendations = [];

  final Map<String, String> seasons = {
    'hot_humid': '☀️ ပူအိုက်သော ရာသီ (Hot & Humid)',
    'rainy_cozy': '🌧️ မိုးအေးသော ရာသီ (Rainy & Cozy)',
    'cool_aircon': '❄️ Air-con ခန်း / ဆောင်းရာသီ',
    'all_season': '✨ ရာသီမရွေး (All Season)',
  };

  final Map<String, String> occasions = {
    'daily_uni': '🎒 နေ့စဉ် / ကျောင်းသွား (Daily / Uni)',
    'office': '💼 ရုံးတက် / ပွဲတက် (Office / Formal)',
    'date_night': '🍷 Date Night / ညပွဲ',
  };

  final Map<String, String> vibes = {
    'fresh_clean': '🌊 သန့်ရှင်းလန်းဆန်းသော (Fresh & Clean)',
    'sweet_cozy': '🍦 ချိုမြိန်နွေးထွေးသော (Sweet & Cozy)',
    'bold_mysterious': '🔥 ဆွဲဆောင်မှုရှိပြီး တည်ကြည်သော (Bold)',
  };

  final List<String> availableNotes = ['citrus', 'aquatic', 'woody', 'vanilla', 'amber', 'incense', 'musk', 'spicy'];

  Future<void> getRecommendations() async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/recommend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'season': selectedSeason,
          'occasion': selectedOccasion,
          'vibe': selectedVibe,
          'preferred_notes': selectedNotes,
        }),
      );
      if (response.statusCode == 200) {
        setState(() {
          recommendations = jsonDecode(response.body)['recommendations'];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FIND UR SCENT • AI ENGINE', style: TextStyle(color: Color(0xFFD4AF37), letterSpacing: 3, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('သင်နှင့် အလိုက်ဖက်ဆုံး ရေမွှေးကို ရှာဖွေပါ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildTitle('၁။ ဘယ်လို ရာသီဥတုမှာ ဆွတ်မှာလဲ?'),
          _buildChips(seasons, selectedSeason, (v) => setState(() => selectedSeason = v)),
          const SizedBox(height: 18),
          _buildTitle('၂။ ဘယ်နေရာတွေကို သွားဖို့လဲ?'),
          _buildChips(occasions, selectedOccasion, (v) => setState(() => selectedOccasion = v)),
          const SizedBox(height: 18),
          _buildTitle('၃။ ဘယ်လို Vibe မျိုး လိုချင်တာလဲ?'),
          _buildChips(vibes, selectedVibe, (v) => setState(() => selectedVibe = v)),
          const SizedBox(height: 18),
          _buildTitle('၄။ နှစ်သက်သော အနံ့များ (Notes) ရွေးပါ'),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: availableNotes.map((note) {
              final isSelected = selectedNotes.contains(note);
              return FilterChip(
                label: Text(note.toUpperCase()), selected: isSelected,
                selectedColor: const Color(0xFFD4AF37).withValues(alpha: 0.3), checkmarkColor: const Color(0xFFD4AF37),
                onSelected: (sel) => setState(() => sel ? selectedNotes.add(note) : selectedNotes.remove(note)),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: isLoading ? null : getRecommendations,
              child: isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('AI ဖြင့် ရေမွှေးရွေးချယ်မည် ✨', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text('သင့်အတွက် အသင့်တော်ဆုံး ရေမွှေးများ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
            const SizedBox(height: 16),
            ...recommendations.map((p) => PerfumeGlassCard(perfume: p, isSaved: widget.isSaved(p['id']), onToggleSave: () => widget.onToggleSave(p), onLogSotd: () => widget.onLogSotd(p))),
          ],
        ],
      ),
    );
  }
  Widget _buildTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)));
  Widget _buildChips(Map<String, String> opts, String cur, Function(String) onSelect) => Wrap(
    spacing: 8, runSpacing: 8,
    children: opts.entries.map((e) => ChoiceChip(
      label: Text(e.value), selected: cur == e.key, selectedColor: const Color(0xFFD4AF37),
      labelStyle: TextStyle(color: cur == e.key ? Colors.black : Colors.white, fontWeight: cur == e.key ? FontWeight.bold : FontWeight.normal),
      onSelected: (_) => onSelect(e.key),
    )).toList(),
  );
}

// ==================== TAB 2: EXPLORE CSV (SERVER SEARCH) ====================
class ExplorePerfumesTab extends StatefulWidget {
  final Function(Map<String, dynamic>) onToggleSave;
  final Function(Map<String, dynamic>) onLogSotd;
  final bool Function(int) isSaved;

  const ExplorePerfumesTab({super.key, required this.onToggleSave, required this.onLogSotd, required this.isSaved});

  @override
  State<ExplorePerfumesTab> createState() => _ExplorePerfumesTabState();
}

class _ExplorePerfumesTabState extends State<ExplorePerfumesTab> {
  List<dynamic> filteredPerfumes = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPerfumes('');
  }

  Future<void> _fetchPerfumes(String query) async {
    setState(() => isLoading = true);
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/perfumes?q=$encodedQuery'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['perfumes'] as List<dynamic>;
        setState(() {
          filteredPerfumes = data;
        });
      }
    } catch (e) {
      print("Search Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EXPLORE FRAGRANCE DATABASE', style: TextStyle(color: Color(0xFFD4AF37), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onSubmitted: (val) => _fetchPerfumes(val),
            decoration: InputDecoration(
              hintText: 'ရေမွှေးအမည် သို့မဟုတ် Brand ရှာပါ (ဥပမာ: Versace)...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Color(0xFFD4AF37)),
                onPressed: () => _fetchPerfumes(_searchController.text),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                : filteredPerfumes.isEmpty
                    ? const Center(child: Text('ရှာဖွေထားသော ရေမွှေး မတွေ့ပါ 😢', style: TextStyle(color: Colors.white60)))
                    : ListView.builder(
                        itemCount: filteredPerfumes.length,
                        itemBuilder: (ctx, i) {
                          final p = filteredPerfumes[i];
                          return PerfumeGlassCard(
                            perfume: p,
                            isSaved: widget.isSaved(p['id']),
                            onToggleSave: () => widget.onToggleSave(p),
                            onLogSotd: () => widget.onLogSotd(p),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ==================== TAB 3: MY WARDROBE & SOTD LOG ====================
class WardrobeTab extends StatelessWidget {
  final List<Map<String, dynamic>> wardrobe;
  final List<Map<String, dynamic>> sotdLogs;
  final Function(Map<String, dynamic>) onRemove;
  final Function(Map<String, dynamic>) onLogSotd;

  const WardrobeTab({super.key, required this.wardrobe, required this.sotdLogs, required this.onRemove, required this.onLogSotd});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MY SCENT WARDROBE', style: TextStyle(color: Color(0xFFD4AF37), letterSpacing: 3, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('သိမ်းဆည်းထားသော ရေမွှေးနှင့် နေ့စဉ်မှတ်တမ်း', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('📅 Scent of the Day (နေ့စဉ်ဆွတ်သည့် မှတ်တမ်း)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
          const SizedBox(height: 10),
          if (sotdLogs.isEmpty) const Text('မှတ်တမ်း မရှိသေးပါ။', style: TextStyle(color: Colors.white60))
          else ...sotdLogs.take(5).map((log) => Card(color: Colors.white.withValues(alpha: 0.06), child: ListTile(
            leading: const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37)),
            title: Text(log['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(log['brand']),
            trailing: Text(log['date'], style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ))),
          const SizedBox(height: 28),
          Text('❤️ သိမ်းဆည်းထားသော ရေမွှေးများ (${wardrobe.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
          const SizedBox(height: 12),
          if (wardrobe.isEmpty) const Text('သိမ်းဆည်းထားသော ရေမွှေး မရှိသေးပါ။', style: TextStyle(color: Colors.white60))
          else ...wardrobe.map((p) => PerfumeGlassCard(perfume: p, isSaved: true, onToggleSave: () => onRemove(p), onLogSotd: () => onLogSotd(p))),
        ],
      ),
    );
  }
}

// ==================== SHARED GLASS PERFUME CARD ====================
class PerfumeGlassCard extends StatelessWidget {
  final Map<String, dynamic> perfume;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onLogSotd;

  const PerfumeGlassCard({super.key, required this.perfume, required this.isSaved, required this.onToggleSave, required this.onLogSotd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        perfume['image_url'] ?? '', width: 85, height: 105, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(width: 85, height: 105, color: const Color(0xFF252538), child: const Center(child: Icon(Icons.wine_bar, color: Color(0xFFD4AF37), size: 36))),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(perfume['brand'].toString().toUpperCase(), style: const TextStyle(color: Color(0xFFD4AF37), letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.bold))),
                              IconButton(visualDensity: VisualDensity.compact, icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border, color: isSaved ? Colors.redAccent : Colors.white70), onPressed: onToggleSave),
                            ],
                          ),
                          Text('${perfume['name']} (${perfume['price_tier']})', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8, runSpacing: 4,
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(10)), child: Text('${perfume['match_score'] ?? 95}% Match', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11))),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)), child: Text('⏳ ${perfume['longevity'] ?? "8 hrs"}', style: const TextStyle(fontSize: 11))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 22, color: Colors.white24),
                _buildNoteRow('Top Notes:', perfume['top_notes'] ?? []),
                const SizedBox(height: 4),
                _buildNoteRow('Heart Notes:', perfume['middle_notes'] ?? []),
                const SizedBox(height: 4),
                _buildNoteRow('Base Notes:', perfume['base_notes'] ?? []),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onLogSotd,
                    icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                    label: const Text('Wear Today', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildNoteRow(String label, List<dynamic> notes) {
      if (notes.isEmpty) return const SizedBox.shrink();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 85, child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12))), 
          Expanded(child: Text(notes.join(' • '), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)))
        ],
      );
  }
}