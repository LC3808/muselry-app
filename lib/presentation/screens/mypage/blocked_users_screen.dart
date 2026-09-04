import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/block_provider.dart';
import '../../providers/review_provider.dart';
import '../../widgets/common/user_avatar.dart';

/// 현재 사용자가 차단한 사용자를 조회하고 차단을 해제하는 화면.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsersAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('차단한 사용자 관리')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(blockedUserIdsProvider);
          ref.invalidate(blockedUsersProvider);
          await ref.read(blockedUsersProvider.future);
        },
        child: blockedUsersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 180),
              Center(
                child: Text(
                  '차단한 사용자를 불러오지 못했어요.',
                  style: TextStyle(color: AppTheme.textSecondaryColor),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(blockedUsersProvider),
                  child: const Text('다시 시도'),
                ),
              ),
            ],
          ),
          data: (users) {
            if (users.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  Icon(
                    Icons.block_flipped,
                    size: 44,
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '차단한 사용자가 없습니다.',
                      style: TextStyle(color: AppTheme.textSecondaryColor),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, indent: 72, color: AppTheme.dividerColor),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: UserAvatar(
                    avatarStoragePath: user.avatarStoragePath,
                    avatarUrl: user.avatarUrl,
                    displayName: user.nickname ?? '알 수 없는 사용자',
                    radius: 22,
                  ),
                  title: Text(user.nickname ?? '알 수 없는 사용자'),
                  trailing: OutlinedButton(
                    onPressed: () => _unblockUser(context, ref, user.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimaryColor,
                      side: BorderSide(color: AppTheme.dividerColor),
                    ),
                    child: const Text('차단 해제'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _unblockUser(
    BuildContext context,
    WidgetRef ref,
    String blockedUserId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(blockRepositoryProvider).unblockUser(blockedUserId);
      ref.invalidate(blockedUserIdsProvider);
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(reviewsForMuseumProvider);
      ref.invalidate(museumReviewsProvider);
      ref.invalidate(communityReviewsProvider);

      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('사용자 차단을 해제했습니다.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('차단 해제 중 오류가 발생했습니다: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
