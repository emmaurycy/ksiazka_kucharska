import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('etap 1 - inicjalizacja bazy'))),
    );
  }
}
