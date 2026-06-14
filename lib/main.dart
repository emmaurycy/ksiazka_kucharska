import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox("recipes_box_v1");
  runApp(const MyApp());
}

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

class RecipeDatabase {
  static Box get _box => Hive.box("recipes_box_v1");

  static List<Recipe> getAllRecipes() {
    return _box.values
        .map((item) => Recipe.fromMap(Map<dynamic, dynamic>.from(item)))
        .toList();
  }

  static Future<void> saveRecipes(List<Recipe> recipes) async {
    for (final recipe in recipes) {
      await _box.put(recipe.id, recipe.toMap());
    }
  }

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
}

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
            return Center(child: Text('⚠️ Problem:\n${snapshot.error}'));
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
                    ),
                  ),
                  title: Text(
                    recipe.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Kuchnia: ${recipe.cuisine}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
