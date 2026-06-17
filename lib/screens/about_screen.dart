import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _open(String url, {String? appUrl}) async {
    if (appUrl != null) {
      final appUri = Uri.parse(appUrl);
      if (await canLaunchUrl(appUri)) {
        launchUrl(appUri, mode: LaunchMode.externalNonBrowserApplication);
        return;
      }
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // App identity
          Center(
            child: Column(
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.document_scanner, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 12),
                Text('DSA Malawi', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Version 1.1.0', style: TextStyle(color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text(
                  'A free tool built for Direct Sales Agents in Malawi.\nScan documents, calculate loans — no stationery shop needed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // ── Theme selector ──
          _SectionLabel('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.palette_outlined),
                  const SizedBox(width: 12),
                  const Text('Theme'),
                  const Spacer(),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Auto')),
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
                    ],
                    selected: {appState.themeMode},
                    onSelectionChanged: (v) => appState.setThemeMode(v.first),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          _SectionLabel('Developer'),
          _LinkTile(
            icon: Icons.code,
            color: Colors.black87,
            title: 'GitHub',
            subtitle: '@RedsonNgwira',
            onTap: () => _open('https://github.com/RedsonNgwira'),
          ),
          _LinkTile(
            icon: Icons.alternate_email,
            color: const Color(0xFF1DA1F2),
            title: 'Twitter / X',
            subtitle: '@RedsonNgwira',
            onTap: () => _open(
              'https://twitter.com/RedsonNgwira',
              appUrl: 'twitter://user?screen_name=RedsonNgwira',
            ),
          ),
          _LinkTile(
            icon: Icons.facebook,
            color: const Color(0xFF1877F2),
            title: 'Facebook Page',
            subtitle: 'Redson Ngwira',
            onTap: () => _open(
              'https://web.facebook.com/profile.php?id=61583687080759',
              appUrl: 'fb://profile/61583687080759',
            ),
          ),

          const SizedBox(height: 24),
          _SectionLabel('Support the project'),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.volunteer_activism, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('Buy me airtime 😄', style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary)),
                  ]),
                  const SizedBox(height: 8),
                  const Text('This app is free. If it saves you time, a small Airtel/TNM donation keeps it going.'),
                  const SizedBox(height: 12),
                  _DonateRow('Airtel Money', '0991 234 567'),
                  _DonateRow('TNM Mpamba', '0896 022 284'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          _SectionLabel('Source code'),
          _LinkTile(
            icon: Icons.open_in_new,
            color: scheme.primary,
            title: 'View on GitHub',
            subtitle: 'github.com/RedsonNgwira/dsa_malawi',
            onTap: () => _open('https://github.com/RedsonNgwira/dsa_malawi'),
          ),

          const SizedBox(height: 32),
          Center(child: Text('Made with ❤️ for Malawi', style: TextStyle(color: Colors.grey.shade400))),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
  );
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _LinkTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    ),
  );
}

class _DonateRow extends StatelessWidget {
  final String network, number;
  const _DonateRow(this.network, this.number);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text('$network: ', style: const TextStyle(fontWeight: FontWeight.w600)),
      SelectableText(number),
    ]),
  );
}
