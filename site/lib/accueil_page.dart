// lib/accueil_page.dart
import 'package:flutter/material.dart';
import 'choix_page.dart';
import 'theme_tiger.dart';
import 'main.dart'; // pour accéder à themeNotifier global

class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key});

  void _goToChoixPage(BuildContext context, bool teransible) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChoixPage(teransible: teransible)),
    );
  }

  void _toggleTheme() {
    themeNotifier.value = themeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: Tiger.tigerBackground(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.orange.shade50.withValues(alpha: 0.8),
          title: Text(
            "TIGRES Deploy",
            style: TextStyle(
              color: isDark ? Colors.orangeAccent : Colors.deepOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              tooltip: "Changer le mode d'affichage",
              onPressed: _toggleTheme,
              icon: Icon(
                isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                color: isDark ? Colors.orangeAccent : Colors.deepOrange,
              ),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0E0E0E).withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.orangeAccent.withValues(alpha: 0.6)
                      : Colors.deepOrange.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.orange.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_fix_high_rounded,
                        color: isDark ? Colors.orangeAccent : Colors.deepOrange,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          "Terransible Setup",
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? Colors.orangeAccent
                                : Colors.deepOrangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(
                    color: isDark
                        ? Colors.orangeAccent
                        : Colors.deepOrangeAccent.withValues(alpha: 0.8),
                    thickness: 1,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Votre mission : déployer vos machines comme un vrai tigre.\nAvez-vous déjà Terransible d’installé ?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),

                  /// 🔘 Boutons mieux équilibrés
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _goToChoixPage(context, true),
                          style:
                              Tiger.tigerButton(
                                background: isDark
                                    ? Colors.orangeAccent
                                    : Colors.deepOrangeAccent,
                                foreground: isDark
                                    ? Colors.black
                                    : Colors.white,
                              ).copyWith(
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.check_rounded, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  "Oui, rugissons",
                                  style: TextStyle(fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _goToChoixPage(context, false),
                          style:
                              Tiger.tigerButton(
                                background: isDark
                                    ? Colors.redAccent
                                    : Colors.deepOrange.withValues(alpha: 0.9),
                                foreground: isDark
                                    ? Colors.black
                                    : Colors.white,
                              ).copyWith(
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.close_rounded, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  "Non, en solo",
                                  style: TextStyle(fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "🔥 Créé par des TIGRES, pour des TIGRES.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black54,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
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
}
