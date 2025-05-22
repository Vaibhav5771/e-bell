import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'device_info_page.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange, Colors.orangeAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          image: DecorationImage(
            image: AssetImage('assets/diagonal_lines.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 350,
                        height: 600,
                        color: Colors.grey[300], // Placeholder for QR scanner
                        child: MobileScanner(
                          onDetect: (capture) {
                            if (hasScanned) return; // Prevent multiple scans
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              final String? rawValue = barcode.rawValue;
                              if (rawValue != null) {
                                setState(() {
                                  hasScanned = true;
                                });
                                // For demo purposes, hardcode the values to match the image
                                // In a real app, parse rawValue (e.g., JSON) to extract these fields
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const DeviceInfoPage(
                                      macAddress: 'agybae897rgfueoa',
                                      imei: 'ygd86dfab97',
                                      loremIpsum: 'sduofbs97dfb8',
                                      loremIpsum2: 'uifdq2rg0qbgf2',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Scan the QR code to configure the device',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}