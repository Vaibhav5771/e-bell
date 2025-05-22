import 'package:flutter/material.dart';
import 'package:e_bell/music_tabs/addmusic.dart';
import 'package:e_bell/music_tabs/recordingpage.dart';
import 'package:e_bell/pages/tablogic1.dart';

class MusicLibrary extends StatefulWidget {
  final TabLogic1 tabLogic;

  const MusicLibrary({super.key, required this.tabLogic});

  @override
  _MusicLibraryState createState() => _MusicLibraryState();
}

class _MusicLibraryState extends State<MusicLibrary> {
  bool _isFabMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          Column(
            children: [
              // Custom Tab Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tabs for Events/Tasks and Bell
                    Container(
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
                              onTap: () {
                                print("Switching to Library tab");
                                setState(() {
                                  widget.tabLogic.setSelectedTab(0);
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: widget.tabLogic.buildTab(
                              context: context,
                              text: 'My Music',
                              index: 1,
                              onTap: () {
                                print("Switching to My Music tab");
                                setState(() {
                                  widget.tabLogic.setSelectedTab(1);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Tab Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: widget.tabLogic.selectedTabIndex == 0
                      ? _buildLibraryContent()
                      : _buildMyMusicContent(),
                ),
              ),
            ],
          ),
          // FAB Menu Options
          if (_isFabMenuOpen)
            Positioned(
              bottom: 80,
              right: 16,
              child: Container(
                width: 180,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildFabOption('Add Music', false),
                    _buildFabOption('Record Music', false),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isFabMenuOpen = !_isFabMenuOpen;
          });
        },
        backgroundColor: const Color.fromRGBO(255, 152, 0, 1),
        shape: const CircleBorder(),
        child: Icon(
          _isFabMenuOpen ? Icons.close : Icons.music_note,
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  // Library Content (Category Grid + Trending List)
  Widget _buildLibraryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Category'),
        _buildCategoryGrid(),
        _buildSectionTitle('Trending Music'),
        _buildTrendingList(),
      ],
    );
  }

  // My Music Content
  Widget _buildMyMusicContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Your Music'),
        _buildMyMusicList(),
      ],
    );
  }

  // FAB Option
  Widget _buildFabOption(String title, bool isChecked) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          setState(() => _isFabMenuOpen = false);
          switch (title) {
            case 'Add Music':
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddmusicPage()),
              );
              setState(() {}); // Refresh content
              break;
            case 'Record Music':
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RecordMusicPage()),
              );
              setState(() {}); // Refresh content
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Section Title
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Category Grid
  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: AssetImage('assets/Music.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: const Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Category',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Trending List
  Widget _buildTrendingList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 2,
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
            ),
          );
        },
      ),
    );
  }

  // My Music List
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
