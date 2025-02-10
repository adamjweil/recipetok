// Move time formatting functions
String getTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  
  if (difference.inMinutes < 1) {
    return 'just now';
  } else if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else if (difference.inDays < 30) {
    return '${(difference.inDays / 7).floor()}w ago';
  } else if (difference.inDays < 365) {
    return '${(difference.inDays / 30).floor()}mo ago';
  } else {
    return '${(difference.inDays / 365).floor()}y ago';
  }
}

String formatViewCount(int viewCount) {
  if (viewCount < 1000) return viewCount.toString();
  if (viewCount < 1000000) return '${(viewCount / 1000).toStringAsFixed(1)}K';
  return '${(viewCount / 1000000).toStringAsFixed(1)}M';
}

String formatCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '${(count / 1000000).toStringAsFixed(1)}M';
} 