/// 编辑器支持高亮的语言。
class LanguageSpec {
  const LanguageSpec._(this.id, this.label);

  final String id;
  final String label;

  static const dart = LanguageSpec._('dart', 'Dart');
  static const yaml = LanguageSpec._('yaml', 'YAML');
  static const json = LanguageSpec._('json', 'JSON');
  static const markdown = LanguageSpec._('markdown', 'Markdown');
  static const plain = LanguageSpec._('plain', '纯文本');

  static LanguageSpec forPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.dart')) return dart;
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return yaml;
    if (lower.endsWith('.json')) return json;
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return markdown;
    return plain;
  }
}
