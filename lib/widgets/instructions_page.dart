import 'package:flutter/material.dart';

class InstructionsPage extends StatefulWidget {
  const InstructionsPage({super.key});

  @override
  State<InstructionsPage> createState() => _InstructionsPageState();
}

class _InstructionsPageState extends State<InstructionsPage> {
  bool isWolof = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Text('FR', style: TextStyle(fontWeight: FontWeight.bold)),
                Switch(
                  value: isWolof,
                  onChanged: (value) {
                    setState(() {
                      isWolof = value;
                    });
                  },
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.blue[800],
                  inactiveTrackColor: Colors.blue[100],
                ),
                const Text('WO', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                isWolof ? 'Naka lañu ciyaar' : 'Comment jouer',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _Section(
              title: isWolof ? 'Gisal ay baat yu bare ci 7 araf yi ñu jox.' : 'Trouvez autant de mots que possible en utilisant les 7 lettres proposées.',
              content: '',
              theme: theme,
            ),
            const SizedBox(height: 16),
            _Section(
              title: isWolof ? 'Sart yi :' : 'Règles :',
              items: isWolof
                  ? [
                      'Baat bi war na am lu gën a tollu ci 3 araf.',
                      'Baat bi war na am araf bu digg bi.',
                      'Mën nga jëfandikoo araf yi lu bari (lu bari yoon).',
                      'Turu nit ak jëmmali (abréviation) duñu ko nangu.',
                    ]
                  : [
                      'Chaque mot doit contenir au moins 3 lettres.',
                      'Chaque mot doit contenir la lettre centrale.',
                      'Les lettres peuvent être utilisées plusieurs fois.',
                      'Les noms propres et les abréviations ne sont pas autorisés.',
                    ],
              theme: theme,
            ),
            const SizedBox(height: 16),
            _Section(
              title: isWolof ? 'Point yi :' : 'Score :',
              items: isWolof
                  ? ['Baat bu baax bu nekk mooy 1 point.']
                  : ['Chaque mot valide rapporte 1 point.'],
              theme: theme,
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                isWolof ? 'Jàmm rekk ak mbégt' : 'Bonne chance et amusez-vous',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? content;
  final List<String>? items;
  final ThemeData theme;

  const _Section({
    required this.title,
    this.content,
    this.items,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        if (content != null && content!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            content!,
            style: theme.textTheme.bodyLarge,
          ),
        ],
        if (items != null) ...[
          const SizedBox(height: 8),
          ...items!.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}
