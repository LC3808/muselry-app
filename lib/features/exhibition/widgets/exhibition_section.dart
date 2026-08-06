import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html_unescape/html_unescape.dart';

import '../../../config/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/museum_repository.dart';
import '../../../domain/models/museum.dart';
import '../exhibition_model.dart';
import '../exhibition_provider.dart';
import 'exhibition_card.dart';

final _unescape = HtmlUnescape();

/// 홈 화면 "내 주변 문화행사" 섹션
/// - 비동기 독립 로딩 (홈 전체 렌더링 차단 없음)
/// - 결과 0건 또는 API 실패 시 섹션 자체 숨김
class ExhibitionSection extends ConsumerWidget {
  const ExhibitionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(exhibitionProvider);

    return asyncState.when(
      loading: () => const _ExhibitionLoading(),
      error: (_, __) => const SizedBox.shrink(), // 에러 시 섹션 숨김
      data: (state) {
        if (state.items.isEmpty) return const SizedBox.shrink();
        return _ExhibitionContent(state: state);
      },
    );
  }
}

class _ExhibitionContent extends StatelessWidget {
  final ExhibitionState state;
  const _ExhibitionContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더 (외부 padding 없음 — home_screen.dart EdgeInsets.all(20)에 정렬)
        Row(
          children: [
            const Text(
              '내 주변 문화행사',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(width: 6),
            if (state.hasLocation)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '거리순',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // 가로 스크롤 카드 리스트 (외부 padding 없음 — home_screen.dart EdgeInsets.all(20)에 정렬)
        // 카드 높이: 이미지 100 + 패딩 16 + 배지 16 + 제목 32 + 장소 14 + 기간 12 + 여백 = 228
        SizedBox(
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final exhibition = state.items[index];
              return ExhibitionCard(
                exhibition: exhibition,
                userLat: state.userLat,
                userLng: state.userLng,
                onTap: () => _showDetail(context, exhibition, state),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(
      BuildContext context, Exhibition exhibition, ExhibitionState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExhibitionDetailSheet(
        exhibition: exhibition,
        userLat: state.userLat,
        userLng: state.userLng,
      ),
    );
  }
}

/// 문화행사 상세 모달
/// - 썸네일·배지·제목·장소·기간·거리 표시
/// - 뮤즐리 등록 시설이면 "장소 정보 보기" 버튼 조건부 표시
/// - 외부 URL 없음 (period2 응답 url/homepage 전부 빈 값 확인됨)
/// - 문화행사 데이터 Supabase 저장 없음, museums 병합 없음
class _ExhibitionDetailSheet extends StatefulWidget {
  final Exhibition exhibition;
  final double? userLat;
  final double? userLng;
  const _ExhibitionDetailSheet({
    required this.exhibition,
    this.userLat,
    this.userLng,
  });

  @override
  State<_ExhibitionDetailSheet> createState() => _ExhibitionDetailSheetState();
}

class _ExhibitionDetailSheetState extends State<_ExhibitionDetailSheet> {
  Museum? _matchedMuseum;
  bool _lookupDone = false;

  @override
  void initState() {
    super.initState();
    _lookupMuseum();
  }

  Future<void> _lookupMuseum() async {
    final place = _unescape.convert(widget.exhibition.place);
    if (kDebugMode) {
      print('EXH: place="$place" — looking up museum match');
    }
    final museum = await MuseumRepository().findMuseumByName(place);
    if (kDebugMode) {
      print('EXH: place="$place" museumMatch=${museum?.id ?? "none"}');
    }
    if (mounted) {
      setState(() {
        _matchedMuseum = museum;
        _lookupDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exhibition;
    final title = _unescape.convert(ex.title);
    final place = _unescape.convert(ex.place);

    // 거리 계산 (위치 있을 때만)
    String? distanceText;
    if (widget.userLat != null &&
        widget.userLng != null &&
        ex.latitude != null &&
        ex.longitude != null) {
      final d = _haversineKm(
          widget.userLat!, widget.userLng!, ex.latitude!, ex.longitude!);
      distanceText = d < 1.0
          ? '${(d * 1000).round()}m'
          : '${d.toStringAsFixed(1)}km';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 드래그 핸들
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // 썸네일 (크게)
            if (ex.thumbnail != null && ex.thumbnail!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    ex.thumbnail!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // 분야 배지
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _RealmBadge(realm: ex.realmName),
                  ),
                  const SizedBox(height: 10),
                  // 제목 (HTML 디코딩)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 장소 (HTML 디코딩)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: place,
                  ),
                  const SizedBox(height: 8),
                  // 기간 (연도 포함)
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: '행사 기간: ${ex.displayPeriod}',
                  ),
                  // 거리 (위치 있을 때만)
                  if (distanceText != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.near_me_outlined,
                      text: distanceText,
                    ),
                  ],
                  // 지역
                  if (ex.area != null || ex.sigungu != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.map_outlined,
                      text: [ex.area, ex.sigungu]
                          .whereType<String>()
                          .join(' '),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // "장소 정보 보기" 버튼 — 매칭 성공 시만 표시
                  if (_lookupDone && _matchedMuseum != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push(AppRoutes.museumDetail
                              .replaceFirst(':id', _matchedMuseum!.id));
                        },
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('장소 정보 보기'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상세 모달 내 분야 배지 (exhibition_card.dart의 _RealmBadge와 동일 색상 규칙)
class _RealmBadge extends StatelessWidget {
  final String realm;
  const _RealmBadge({required this.realm});

  @override
  Widget build(BuildContext context) {
    final trimmed = realm.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final (bg, fg) = _colors(trimmed);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        trimmed,
        style: TextStyle(
          fontSize: 11,
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color) _colors(String r) {
    switch (r) {
      case '전시':
        return (AppTheme.primaryColor.withValues(alpha: 0.12), AppTheme.primaryColor);
      case '교육/체험':
        return (const Color(0xFF27AE60).withValues(alpha: 0.12), const Color(0xFF27AE60));
      case '행사/축제':
        return (const Color(0xFFE67E22).withValues(alpha: 0.12), const Color(0xFFE67E22));
      default:
        return (AppTheme.dividerColor, AppTheme.textSecondaryColor);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180;

/// 로딩 shimmer (인기 장소 로딩과 동일한 높이)
class _ExhibitionLoading extends StatelessWidget {
  const _ExhibitionLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 100,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Container(
              width: 160,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
