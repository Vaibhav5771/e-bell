import 'package:flutter/material.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.orange),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Smart E-Bell'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'E-Bell v1.0',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Lorem ipsum odor amet, consectetur adipiscing elit. Neque integer ante dapibus lacinia vel in. Auctor mus elementum aptent adipiscing inceptos montes. Hendrerit ante metus pellentesque porta, metus finibus viverra sodales? Etiam pellentesque cras ornare; montes facilisi commodo. Dui inceptos himendeos elementum dolor id. Auctor quam nam semper a tristique quam dolor. Lobortis nunc varius dis pulvinar nibh velit. Cras diam pharetra suspendisse ultricies sodales at.\n\n'
                  'Fermentum mi posuere dapibus adipiscing convallis pharetra dis convallis. Mollis senectus potenti condimentum mollis porttitor fermentum lobortis porta lacus. Mattis consequat efficitur pellentesque nullam aenean ultriceorper maecenas sociosqu pharetra. Aliquam fusellus netus praesent quis nunc montes pulvinar auctor vulputate. Adipiscing sollicitudin penatibus sollicitudin, fermentum dictum velit. Vel cras blandit, praesent ornare turpis ex etiam imperdiet amet. Mauris lacinia curae finibus tristique ante. Placerat cras cras fusce, luctus curabitur aenean.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const Spacer(),
            const Center(
              child: Column(
                children: [
                  Text(
                    'Powered by',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'IO Genies Solutions',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}