import 'package:flutter/material.dart';
import 'package:e_bell/music_tabs/addmusic.dart';
import 'package:e_bell/music_tabs/recordingpage.dart';
import 'package:e_bell/pages/music_library.dart';
import '../pages/tablogic1.dart';

class MyMusicPage extends StatefulWidget {
  final TabLogic1 tabLogic; // Accept TabLogic1 instance

  const MyMusicPage({super.key, required this.tabLogic});

  @override
  _MyMusicPageState createState() => _MyMusicPageState();
}

class _MyMusicPageState extends State<MyMusicPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Custom Tab Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 35,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: widget.tabLogic.buildTab(
                      context: context,
                      text: 'Library',
                      index: 0,
                      isSelected: widget.tabLogic.selectedTabIndex == 0,
                      onTap: () {
                        widget.tabLogic.setSelectedTab(0);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MusicLibrary(tabLogic: widget.tabLogic),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: widget.tabLogic.buildTab(
                      context: context,
                      text: 'My Music',
                      index: 1,
                      isSelected: widget.tabLogic.selectedTabIndex == 1,
                      onTap: () {
                        widget.tabLogic.setSelectedTab(1);
                        // No need to navigate since we're already on My Music
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // My Music Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Your Music'),
                  _buildMyMusicList(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showFabMenu(context);
        },
        backgroundColor: const Color.fromRGBO(255, 152, 0, 1),
        shape: const CircleBorder(),
        child: const Icon(
          Icons.music_note,
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  // Shows a Stati bottom sheet for FAB options
  void _showFabMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Music Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFabOption(
                context,
                title: 'Add Music',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddmusicPage()),
                  );
                },
              ),
              _buildFabOption(
                context,
                title: 'Record Music',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RecordMusicPage()),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Builds a widget for each FAB option in the bottom sheet
  Widget _buildFabOption(BuildContext context,
      {required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMyMusicList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/Music.jpg',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text('Song ${index + 1}'),
              subtitle: const Text('00:00'),
              trailing: const Icon(
                Icons.play_circle_fill,
                color: Colors.orange,
                size: 30,
              ),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}