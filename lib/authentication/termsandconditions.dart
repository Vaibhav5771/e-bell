import 'package:e_bell/tabs_planner/themes.dart';
import 'package:flutter/material.dart';
import '../pages/device_page.dart';// Make sure this import points to your DevicePage

class TermsAndConditionsPage extends StatefulWidget {
  const TermsAndConditionsPage({Key? key}) : super(key: key);

  @override
  State<TermsAndConditionsPage> createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      if (!_isScrolledToBottom && maxScroll - currentScroll <= 50) {
        setState(() {
          _isScrolledToBottom = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTermsCard(),
            _buildButtonSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      color: Colors.grey.shade100,
      child: const Text(
        'Terms & Conditions',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildTermsCard() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: Card(
          elevation: 3,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(10),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            '1. Acceptance of Terms',
                            'By downloading, installing, or using the Buzzerra app, you agree to these Terms & Conditions. If you do not accept these terms, please do not use the app. Continued use after any updates means you accept the revised terms.',
                          ),
                          _buildSection(
                            '2. About the App',
                            'Buzzerra is a smart audio platform for community notifications and announcements. It allows users to schedule and trigger event-based sound playback including alarms, music, announcements, and alerts. The app integrates with IoT devices and smart bell hardware for automated audio control in housing societies, schools, industries, and smart cities.',
                          ),
                          _buildSection(
                            '3. User Content & Responsibility',
                            'All audio content is created, uploaded, and managed entirely by users. SAM Tech AIoT Solutions LLP does not provide or review any content. You must own or have legal rights to use any audio you upload. You are solely responsible for all content broadcast through the app, including ensuring you have proper licenses and permissions. Uploading copyrighted content without authorization may result in legal consequences under intellectual property laws.',
                          ),
                          _buildSection(
                            '4. Prohibited Use',
                            'You agree not to use the app to upload or broadcast content that is unlawful, vulgar, offensive, defamatory, or infringes on third-party rights including intellectual property and privacy rights. You must not disrupt the functionality of the app, violate local sound pollution or broadcasting regulations, or use the app for any illegal or harmful purposes.',
                          ),
                          _buildSection(
                            '5. Platform Disclaimer & Liability',
                            'Buzzerra functions solely as a trigger-based playback system. The company does not monitor, review, host, or control any user-uploaded content. SAM Tech AIoT Solutions LLP is not liable for any user-generated content, misuse of the app, or any damages arising from app usage. The app is provided "as is" without warranties of any kind.',
                          ),
                          _buildSection(
                            '6. Indemnification',
                            'You agree to indemnify and hold harmless SAM Tech AIoT Solutions LLP, its directors, employees, and affiliates from any claims, losses, damages, or expenses (including legal fees) related to content you upload, your misuse of the app, or violations of these terms or applicable laws.',
                          ),
                          _buildSection(
                            '7. Termination & Modifications',
                            'We reserve the right to suspend or terminate your access to the app at any time for breach of these terms, without notice. We may also modify these terms periodically, and your continued use indicates acceptance of the updated terms.',
                          ),
                          _buildSection(
                            '8. Contact Information',
                            'For questions or concerns regarding these Terms & Conditions:\n\nSAM Tech AIoT Solutions LLP\nEmail: [Insert Email Address]\nAddress: [Insert Physical Address]',
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '© 2025 SAM Tech AIoT Solutions LLP. All rights reserved.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_isScrolledToBottom) _buildScrollHint(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: Colors.amber.shade50,
      child: Row(
        children: [
          Icon(Icons.arrow_downward, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Please scroll down to read all terms',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _handleDecline(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Decline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isScrolledToBottom
                  ? () => _handleAccept(context)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                disabledForegroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Accept',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDecline(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms Declined'),
        content: const Text(
          'You must accept the Terms & Conditions to use Buzzerra. The app will now close.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleAccept(BuildContext context) {
    // Navigate directly to DevicePage
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const ThemePage(),
      ),
    );
  }
}
