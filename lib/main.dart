import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'dart:convert';

void main() async {
  // bindowanie flutera zeby baza dzialala przed startem apki
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // otwieramy kontener na przepisy
  await Hive.openBox("recipes_box_v1");
  runApp(const MyApp());
}

// model danych dla przepisu
class Recipe {
  final int id;
  final String name;
  final List<String> ingredients;
  final List<String> instructions;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty;
  final String cuisine;
  final String image;
  final double rating;

  Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.instructions,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.difficulty,
    required this.cuisine,
    required this.image,
    required this.rating,
  });

  // zamiana obiektu na mape do bazy hive
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "ingredients": ingredients,
      "instructions": instructions,
      "prepTimeMinutes": prepTimeMinutes,
      "cookTimeMinutes": cookTimeMinutes,
      "difficulty": difficulty,
      "cuisine": cuisine,
      "image": image,
      "rating": rating,
    };
  }

  // tworzenie obiektu z jsona z sieci
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json["id"] ?? 0,
      name: json["name"] ?? "Brak nazwy",
      ingredients: List<String>.from(json["ingredients"] ?? []),
      instructions: List<String>.from(json["instructions"] ?? []),
      prepTimeMinutes: json["prepTimeMinutes"] ?? 0,
      cookTimeMinutes: json["cookTimeMinutes"] ?? 0,
      difficulty: json["difficulty"] ?? "Latwy",
      cuisine: json["cuisine"] ?? "Inna",
      image: json["image"] ?? "",
      rating: (json["rating"] ?? 0.0).toDouble(),
    );
  }

  // wyciaganie danych z mapy z bazy offline
  factory Recipe.fromMap(Map<dynamic, dynamic> map) {
    return Recipe(
      id: map["id"],
      name: map["name"],
      ingredients: List<String>.from(map["ingredients"]),
      instructions: List<String>.from(map["instructions"]),
      prepTimeMinutes: map["prepTimeMinutes"],
      cookTimeMinutes: map["cookTimeMinutes"],
      difficulty: map["difficulty"],
      cuisine: map["cuisine"],
      image: map["image"],
      rating: map["rating"],
    );
  }
}

// warstwa bazy danych do trybu ofline
class RecipeDatabase {
  static Box get _box => Hive.box("recipes_box_v1");

  // pobieranie wszystkich zapizanych przepisow
  static List<Recipe> getAllRecipes() {
    return _box.values
        .map((item) => Recipe.fromMap(Map<dynamic, dynamic>.from(item)))
        .toList();
  }

  // szukanie przepisu po id
  static Recipe? getRecipeById(int id) {
    final data = _box.get(id);
    if (data == null) return null;
    return Recipe.fromMap(Map<dynamic, dynamic>.from(data));
  }

  // zapisywanie listy do hive
  static Future<void> saveRecipes(List<Recipe> recipes) async {
    for (final recipe in recipes) {
      await _box.put(recipe.id, recipe.toMap());
    }
  }

  // sprawdzanie czy baza jest pusta
  static bool isEmpty() => _box.isEmpty;
}

// warstwa sieciowa api
class RecipeApiService {
  static const String baseUrl = "https://dummyjson.com/recipes";

  // zapytanie nr 1 - pobranie calej listy przepisow
  static Future<List<Recipe>> fetchRecipesList() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List recipesJson = data["recipes"] ?? [];
      return recipesJson.map((json) => Recipe.fromJson(json)).toList();
    } else {
      throw Exception("Blad sieci");
    }
  }

  // zapytanie nr 2 - szczegoly jednego przepisu po id
  static Future<Recipe> fetchRecipeDetails(int id) async {
    final response = await http.get(Uri.parse("$baseUrl/$id"));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return Recipe.fromJson(data);
    } else {
      throw Exception("Blad ladowania szczegolow");
    }
  }
}

// glowna klasa aplikacji ustawia motyw
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ksiazka Kucharska',
      theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: true),
      home: const RecipeListScreen(),
    );
  }
}

// ekran numer jeden z lista elementow
class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  late Future<List<Recipe>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = _loadInitialData();
  }

  // ladowanie danych na start, bierze z sieci a jak nie ma to z bazy
  Future<List<Recipe>> _loadInitialData() async {
    try {
      if (RecipeDatabase.isEmpty()) {
        final apiRecipes = await RecipeApiService.fetchRecipesList();
        await RecipeDatabase.saveRecipes(apiRecipes);
      }
    } catch (e) {
      if (RecipeDatabase.isEmpty()) {
        rethrow;
      }
    }
    return RecipeDatabase.getAllRecipes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍳 Ksiazka Kucharska'),
        backgroundColor: Colors.orange[100],
      ),
      // ładowanie elementow przez futurebuildera z obsluga bledow i oczekiwania
      body: FutureBuilder<List<Recipe>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '⚠️ Problem:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }

          final recipes = snapshot.data ?? [];
          // rysowanie listy na ekranie
          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      recipe.image,
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.restaurant, size: 40),
                    ),
                  ),
                  title: Text(
                    recipe.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Kuchnia: ${recipe.cuisine} | Czas: ${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  // przejscie do drugiego ekranu szczegolow po kliknieciu
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RecipeDetailScreen(recipeId: recipe.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ekran numer dwa czyli szczegoly wybranego przepisu
class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Future<Recipe> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetails();
  }

  // pobieranie detali, najpierw api i aktualizacja bazy
  Future<Recipe> _loadDetails() async {
    try {
      final apiRecipe = await RecipeApiService.fetchRecipeDetails(
        widget.recipeId,
      );
      await RecipeDatabase.saveRecipes([apiRecipe]);
      return apiRecipe;
    } catch (e) {
      final localRecipe = RecipeDatabase.getRecipeById(widget.recipeId);
      if (localRecipe != null) {
        return localRecipe;
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Szczegoly Przepisu')),
      body: FutureBuilder<Recipe>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '⚠️ Blad:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final recipe = snapshot.data!;
          // caly widok przewijany ze skladnikami i instrukcjami
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(
                  recipe.image,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 100),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Kuchnia: ${recipe.cuisine} • Trudnosc: ${recipe.difficulty} • Ocena: ⭐ ${recipe.rating}',
                        style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '⏱️ Czas przygotowania: ${recipe.prepTimeMinutes} min | Gotowanie: ${recipe.cookTimeMinutes} min',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '🥗 Skladniki:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // mapowanie listy skladnikow na widgety tekstowe
                      ...recipe.ingredients.map(
                        (ing) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• $ing',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '📝 Instrukcja krok po kroku:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // petla do wyswietlania ponumerowanych krokow instrukcji
                      ...recipe.instructions.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${entry.key + 1}. ${entry.value}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
