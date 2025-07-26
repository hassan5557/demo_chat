import 'package:flutter/material.dart';
import '../services/local_database_service.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  Map<String, int> stats = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final databaseStats = await LocalDatabaseService.getDatabaseStats();
      setState(() {
        stats = databaseStats;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    try {
      await LocalDatabaseService.clearAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared')),
      );
      _loadStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh Stats',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Database Statistics',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ...stats.entries.map((entry) => Card(
                        child: ListTile(
                          title: Text(entry.key.toUpperCase()),
                          subtitle: Text('Count: ${entry.value}'),
                          trailing: Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(height: 30),
                  const Text(
                    'Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _clearAllData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Clear All Data'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Note: This will clear all local data including messages, users, groups, and members.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }
} 