/// 文件树中的一个节点（文件或目录）。
class FileNode {
  const FileNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
  });

  final String name;
  final String path;
  final bool isDirectory;
  final List<FileNode> children;

  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}
