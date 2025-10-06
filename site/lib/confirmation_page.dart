// lib/confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme_tiger.dart';

class ConfirmationPage extends StatelessWidget {
  final String fileUrl;
  final String curl;
  final Map<String, dynamic> querry;
  final bool teransible;

  const ConfirmationPage({
    super.key,
    required this.fileUrl,
    required this.curl,
    required this.querry,
    required this.teransible,
  });

  @override
  Widget build(BuildContext context) {
    return TigerAnimatedBG(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: .7),
          title: const Text("TIGRES • Confirmation"),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF141414).withValues(alpha: .95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: .5),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "🐅 Déploiement prêt",
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),

                  _copyRow(
                    context,
                    title: "URL du .auto.tfvars",
                    value: fileUrl,
                    accent: true,
                  ),
                  const SizedBox(height: 16),
                  _copyRow(
                    context,
                    title: "Commande cURL",
                    value: curl,
                    smallMono: true,
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text("Retour"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(160, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _copyRow(
    BuildContext context, {
    required String title,
    required String value,
    bool accent = false,
    bool smallMono = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.white.withValues(alpha: .75)),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: SelectableText(
                  value,
                  style: TextStyle(
                    color: accent ? Colors.orangeAccent : Colors.white,
                    fontFamily: "monospace",
                    fontSize: smallMono ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Copié dans le presse-papiers")),
              );
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text("Copier"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            foregroundColor: Colors.black,
            minimumSize: const Size(120, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}
