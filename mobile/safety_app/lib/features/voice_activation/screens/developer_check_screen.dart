import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class DeveloperCheckScreen extends StatefulWidget {
  const DeveloperCheckScreen({super.key});

  @override
  State<DeveloperCheckScreen> createState() => _DeveloperCheckScreenState();
}

class _DeveloperCheckScreenState extends State<DeveloperCheckScreen> {
  List<File> files = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _loadFiles();

    // Reset currentlyPlaying when audio finishes
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        currentlyPlaying = null;
      });
    });
  }

  Future<void> _loadFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final fileList = dir
        .listSync()
        .whereType<File>() // Only include files
        .toList();

    print("Files found: ${fileList.map((f) => f.path).toList()}");

    setState(() {
      files = fileList;
    });
  }

  Future<void> _playFile(File file) async {
    try {
      if (currentlyPlaying == file.path) {
        // Stop if already playing
        await _audioPlayer.stop();
        setState(() {
          currentlyPlaying = null;
        });
        return;
      }

      // Stop any other audio first
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(file.path));

      setState(() {
        currentlyPlaying = file.path;
      });
    } catch (e) {
      print("Error playing file: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stored Voice Files"),
        backgroundColor: Colors.red,
      ),
      body: files.isEmpty
          ? const Center(child: Text("No recorded voice files found"))
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (_, index) {
                final file = files[index];
                final fileName = file.path.split('/').last;
                final isPlaying = currentlyPlaying == file.path;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Icon(Icons.mic, color: Colors.black54),
                    title: Text(fileName),
                    trailing: IconButton(
                      icon: Icon(
                        isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                        color: isPlaying ? Colors.red : Colors.blue,
                        size: 32,
                      ),
                      onPressed: () => _playFile(file),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
