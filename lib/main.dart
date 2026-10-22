
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const MyApp(),
    ),
  );
}

class AppProvider extends ChangeNotifier {
  String name = '';
  String email = '';
  bool isLoggedIn = false;
  bool isDarkMode = false;
  bool isLoading = true;
  int visitCount = 0;
  List<String> favorites = [];

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    name = prefs.getString('user_name') ?? '';
    email = prefs.getString('user_email') ?? '';
    isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    favorites = prefs.getStringList('favorites') ?? [];

    visitCount = (prefs.getInt('visit_count') ?? 0) + 1;
    await prefs.setInt('visit_count', visitCount);

    isLoading = false;
    notifyListeners();
  }

  AppProvider() {
    loadData();
  }

  Future<void> toggleTheme() async {
    isDarkMode = !isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDarkMode);
    notifyListeners();
  }

  Future<void> saveProfile(String newName, String newEmail) async {
    final prefs = await SharedPreferences.getInstance();

    name = newName;
    email = newEmail;
    isLoggedIn = true;

    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setBool('is_logged_in', true);

    final emails = prefs.getStringList('registered_emails') ?? [];
    if (!emails.contains(email)) {
      emails.add(email);
      await prefs.setStringList('registered_emails', emails);
    }

    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.setBool('is_logged_in', false);

    name = '';
    isLoggedIn = false;
    notifyListeners();
  }

  Future<bool> addFavorite(String item) async {
    final value = item.trim();

    if (value.isEmpty ||
        favorites.any(
          (f) => f.toLowerCase() == value.toLowerCase(),
        )) {
      return false;
    }

    favorites.add(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', favorites);
    notifyListeners();
    return true;
  }

  Future<void> removeFavorite(String item) async {
    favorites.remove(item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', favorites);
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          title: 'State Management',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: provider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: p.toggleTheme,
            icon: Icon(
              p.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
          ),
        ],
      ),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home, size: 80),
                  const SizedBox(height: 16),
                  Text(
                    p.isLoggedIn
                        ? 'Selamat datang, ${p.name}!'
                        : 'Selamat datang, Tamu!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (p.isLoggedIn) Text('Email: ${p.email}'),
                  const SizedBox(height: 16),
                  Text('Kunjungan: ${p.visitCount}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    child: Text(
                      p.isLoggedIn ? 'Lihat Profil' : 'Login / Daftar',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final favoriteController = TextEditingController();
  bool initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!initialized) {
      final p = context.read<AppProvider>();
      nameController.text = p.name;
      emailController.text = p.email;
      initialized = true;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    favoriteController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    if (!formKey.currentState!.validate()) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (RegExp(r'<\s*script\b', caseSensitive: false)
        .hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama mengandung tag terlarang')),
      );
      return;
    }

    final p = context.read<AppProvider>();
    final prefs = await SharedPreferences.getInstance();
    final emails = prefs.getStringList('registered_emails') ?? [];

    if (emails.contains(email) && email != p.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email sudah digunakan')),
      );
      return;
    }

    await p.saveProfile(name, email);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil disimpan')),
    );
  }

  Future<void> addFavorite() async {
    final success = await context
        .read<AppProvider>()
        .addFavorite(favoriteController.text);

    if (!mounted) return;

    if (success) {
      favoriteController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favorit kosong atau sudah ada'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          if (p.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<AppProvider>().logout();
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama tidak boleh kosong';
                        }
                        if (RegExp(
                          r'<\s*script\b',
                          caseSensitive: false,
                        ).hasMatch(value)) {
                          return 'Nama mengandung tag terlarang';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email tidak boleh kosong';
                        }
                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value.trim())) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: saveProfile,
                      child: const Text('Simpan Profil'),
                    ),
                    const Divider(height: 32),
                    const Text(
                      'Daftar Favorit',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: favoriteController,
                      decoration: const InputDecoration(
                        labelText: 'Tambah favorit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: addFavorite,
                      child: const Text('Tambah Favorit'),
                    ),
                    ...p.favorites.map(
                      (item) => ListTile(
                        leading: const Icon(
                          Icons.favorite,
                          color: Colors.pink,
                        ),
                        title: Text(item),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => context
                              .read<AppProvider>()
                              .removeFavorite(item),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Catatan: Jangan menyimpan password '
                      'di SharedPreferences karena data '
                      'tidak terenkripsi.',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
