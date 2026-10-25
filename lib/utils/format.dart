String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final difference = current.difference(time);

  if (difference.isNegative || difference.inMinutes < 1) return '刚刚';
  if (difference.inMinutes < 60) return '${difference.inMinutes} 分钟前';
  if (difference.inHours < 24) return '${difference.inHours} 小时前';
  if (difference.inDays == 1) return '昨天';
  if (difference.inDays < 30) return '${difference.inDays} 天前';

  final local = time.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year/$month/$day';
}
