import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/trace_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MirrorTracingApp());
}

class MirrorTracingApp extends StatelessWidget {
  const MirrorTracingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mirror Tracing App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ParticipantEntryScreen(),
    );
  }
}

class ParticipantEntryScreen extends StatefulWidget {
  const ParticipantEntryScreen({super.key});

  @override
  State<ParticipantEntryScreen> createState() => _ParticipantEntryScreenState();
}

  // ------------------------------
  // INPUT PARTICIPANT INFORMATION 
  // ------------------------------

class _ParticipantEntryScreenState extends State<ParticipantEntryScreen> {
  final TextEditingController idController = TextEditingController();

  String selectedGroup = 'A';        // A, B, or C
  String selectedSession = "encoding";  // encoding, immediate, delayed12, delayed24
  
  bool loading = false;
  List<String> mazeList = [];
 


  // ------------------------------
  // LOAD MAZES 
  // ------------------------------
  Future<void> loadMazes() async {
    setState(() => loading = true);

    final manifestContent =
        await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap =
        json.decode(manifestContent);

    final String basePath =
        'assets/mazes/$selectedGroup/$selectedSession/';

    // DEBUG — keep this while testing
    print('Looking in: $basePath');

    mazeList = manifestMap.keys
        .where((k) => k.startsWith(basePath))
        .where((k) =>
            k.endsWith('.png') ||
            k.endsWith('.jpg') ||
            k.endsWith('.jpeg'))
        .toList();

    mazeList.sort();

    print('Found mazes:');
    mazeList.forEach(print);

    setState(() => loading = false);
  }


  // ------------------------------
  // START TASK
  // ------------------------------
  Future<void> startTask() async {
    await loadMazes();

    if (mazeList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No maze images found!'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraceScreen(
          participantId: idController.text.trim(),
          group: selectedGroup,
          session: selectedSession, 
          mazeList: mazeList,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mirror Tracing — Start")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Participant ID
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: "Participant ID"),
            ),

            const SizedBox(height: 20),
            // GROUP DROPDOWN
            DropdownButton<String>(
              value: selectedGroup,
              items: ['A', 'B', 'C']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedGroup = value!;
                });
              },
            ),
            // SESSION DROPDOWN
            DropdownButtonFormField<String>(
              value: selectedSession,
              decoration: const InputDecoration(labelText: "Session"),
              items: const [
                DropdownMenuItem(
                  value: "encoding",
                  child: Text("Encoding"),
                ),
                DropdownMenuItem(
                  value: "immediate",
                  child: Text("Immediate"),
                ),
                DropdownMenuItem(
                  value: "delayed12",
                  child: Text("Delayed 12hr"),
                ),
                DropdownMenuItem(
                  value: "delayed24",
                  child: Text("Delayed 24hr"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedSession = value!;
                });
              },
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: loading ? null : startTask,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Start"),
            ),
          ],
        ),
      ),
    );
  }
}
