import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_state.dart';
import '../utils/app_text_styles.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    print('AppInfoScreen: Using color ${themeProvider.selectedColor}');
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.selectedColor),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Smart E-Bell',
          style: AppTextStyles.heading,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'E-Bell v2.0',
              style: AppTextStyles.link.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              'Lorem ipsum odor amet, consectetur adipiscing elit. Neque integer ante dapibus lacinia vel in. Auctor mus elementum aptent adipiscing inceptos montes. Hendrerit ante metus pellentesque porta, metus finibus viverra sodales? Etiam pellentesque cras ornare; montes facilisi commodo. Dui inceptos himendeos elementum dolor id. Auctor quam nam semper a tristique quam dolor. Lobortis nunc varius dis pulvinar nibh velit. Cras diam pharetra suspendisse ultricies sodales at.\n\n'
                  'Fermentum mi posuere dapibus adipiscing convallis pharetra dis convallis. Mollis senectus potenti condimentum mollis porttitor fermentum lobortis porta lacus. Mattis consequat efficitur pellentesque nullam aenean ultriceorper maecenas sociosqu pharetra. Aliquam fusellus netus praesent quis nunc montes pulvinar auctor vulputate. Adipiscing sollicitudin penatibus sollicitudin, fermentum dictum velit. Vel cras blandit, praesent ornare turpis ex etiam imperdiet amet. Mauris lacinia curae finibus tristique ante. Placerat cras cras fusce, luctus curabitur aenean.',
              style: AppTextStyles.link.copyWith(height: 1.5),
            ),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Text(
                    'Powered by',
                    style: AppTextStyles.small.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'IO Genies Solutions',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'EBELL_Version_V.2.0',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}