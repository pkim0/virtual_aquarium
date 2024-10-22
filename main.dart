import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(VirtualAquariumApp());
}

class VirtualAquariumApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Aquarium',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AquariumScreen(),
    );
  }
}

class AquariumScreen extends StatefulWidget {
  @override
  _AquariumScreenState createState() => _AquariumScreenState();
}

class _AquariumScreenState extends State<AquariumScreen> with TickerProviderStateMixin {
  List<Fish> fishList = [];
  Color selectedColor = Colors.blue;
  double selectedSpeed = 1.0;
  Random random = Random();
  late AnimationController _controller;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _controller.repeat();
    _loadFishFromDatabase();

    _timer = Timer.periodic(Duration(milliseconds: 100), (Timer t) {
      setState(() {
        fishList.forEach((fish) => fish.updatePosition());
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel();
    super.dispose();
  }

  void _addFish() async {
    if (fishList.length < 10) {
      setState(() {
        fishList.add(Fish(
          color: selectedColor,
          speed: selectedSpeed,
          random: random,
        ));
      });

      final db = await getDatabase();
      await saveFish(db, fishList.last);
    }
  }

  // Function to save all fish to SQLite database
  Future<void> clearAndSaveAllFish() async {
    final db = await getDatabase();
    await db.delete('Fish'); // Clear all fish

    for (var fish in fishList) {
      await saveFish(db, fish);
    }
  }

  // Load fish from SQLite when app starts
  void _loadFishFromDatabase() async {
    final db = await getDatabase();
    List<Fish> loadedFish = await loadFish(db, random);

    setState(() {
      fishList = loadedFish;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Virtual Aquarium'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: clearAndSaveAllFish, // Save the fish to SQLite
          ),
        ],
      ),
      body: Column(
        children: [
          // Aquarium Container
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent,
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: Stack(
              children: fishList.map((fish) => fish.buildFish()).toList(),
            ),
          ),
          Slider(
            value: selectedSpeed,
            min: 0.5,
            max: 5.0,
            divisions: 10,
            label: selectedSpeed.toString(),
            onChanged: (newSpeed) {
              setState(() {
                selectedSpeed = newSpeed;
              });
            },
          ),
          DropdownButton<Color>(
            value: selectedColor,
            items: [
              DropdownMenuItem(
                value: Colors.blue,
                child: Text('Blue'),
              ),
              DropdownMenuItem(
                value: Colors.red,
                child: Text('Red'),
              ),
              DropdownMenuItem(
                value: Colors.green,
                child: Text('Green'),
              ),
            ],
            onChanged: (newColor) {
              setState(() {
                selectedColor = newColor!;
              });
            },
          ),
          // Button to Add Fish
          ElevatedButton(
            onPressed: _addFish,
            child: Text('Add Fish'),
          ),
        ],
      ),
    );
  }
}

class Fish {
  Color color;
  double speed;
  Random random;
  double leftPosition;
  double topPosition;

  Fish({required this.color, required this.speed, required this.random})
      : leftPosition = random.nextDouble() * 280,
        topPosition = random.nextDouble() * 280;

  // Move fish randomly in the aquarium
  void updatePosition() {
    leftPosition += (random.nextDouble() * 2 - 1) * speed * 5;
    topPosition += (random.nextDouble() * 2 - 1) * speed * 5;

    if (leftPosition < 0) leftPosition = 0;
    if (topPosition < 0) topPosition = 0;
    if (leftPosition > 280) leftPosition = 280;
    if (topPosition > 280) topPosition = 280;
  }

  Widget buildFish() {
    return Positioned(
      left: leftPosition,
      top: topPosition,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// SQLite database handling

// Get database connection
Future<Database> getDatabase() async {
  var directory = await getApplicationDocumentsDirectory();
  var path = join(directory.path, 'fish_aquarium.db');
  return openDatabase(
    path,
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE Fish (id INTEGER PRIMARY KEY, color TEXT, speed REAL)',
      );
    },
    version: 1,
  );
}

// Save Fish to the database
Future<void> saveFish(Database db, Fish fish) async {
  await db.insert(
    'Fish',
    {
      'color': fish.color.value.toString(),
      'speed': fish.speed,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

// Load Fish from the database
Future<List<Fish>> loadFish(Database db, Random random) async {
  final List<Map<String, dynamic>> maps = await db.query('Fish');
  return List.generate(maps.length, (i) {
    return Fish(
      color: Color(int.parse(maps[i]['color'])),
      speed: maps[i]['speed'],
      random: random,
    );
  });
}