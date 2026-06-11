import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/app_notification.dart';
import '../../providers/comment_provider.dart';

/// 인앱 알림 목록 화면 (M5 MVP)
/// - 댓글 알림만 표시 (type='comment')
/// - 탭 시 해당 리뷰로 이동 + 읽음 처리
/// - 전체 읽음 처리 버튼
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() =>
      _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationNotifierProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          state.whenOrNull(
            data: (list) {
              final hasUnread = list.any((n) => !n.isRead);
              if (!hasUnread) return null;
              return TextButton(
                onPressed: () => ref
                    .read(notificationNotifierProvider.notifier)
                    .markAllAsRead(),
                child: const Text('모두 읽음'),
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('알림을 불러오지 못했어요.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref
                    .read(notificationNotifierProvider.notifier)
                    .fetch(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const _EmptyNotification();
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationNotifierProvider.notifier).fetch(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppTheme.dividerColor),
              itemBuilder: (context, index) {
                return _NotificationItem(
                  notification: list[index],
                  onTap: () => _onTap(list[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onTap(AppNotification notification) {
    // 읽음 처리
    if (!notification.isRead) {
      ref
          .read(notificationNotifierProvider.notifier)
          .markAsRead(notification.id);
    }
    // R5: 리뷰 ID 있으면 단일 리뷰 화면으로 직접 이동 (/reviews/:reviewId)
    if (notification.reviewId != null) {
      context.push('/reviews/${notification.reviewId}');
    }
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread
            ? AppTheme.primaryColor.withValues(alpha: 0.04)
            : null,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('💬', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            // 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내 리뷰에 댓글이 달렸어요',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // 읽지 않음 표시 (빨간 점)
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFE74C3C),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyNotification extends StatelessWidget {
  const _EmptyNotification();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            '새로운 알림이 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '내 리뷰에 댓글이 달리면 알려드릴게요',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
