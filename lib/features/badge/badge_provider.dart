import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/visit_provider.dart';
import 'badge_model.dart';

/// Badge 화면에서 사용하는 계산 결과입니다.
class BadgeCollectionState {
  final List<BadgeProgress> milestones;
  final List<BadgeProgress> nationalMuseums;

  const BadgeCollectionState({
    required this.milestones,
    required this.nationalMuseums,
  });

  int get earnedMilestoneCount =>
      milestones.where((badge) => badge.isEarned).length;

  int get earnedNationalMuseumCount =>
      nationalMuseums.where((badge) => badge.isEarned).length;
}

/// 기존 방문 기록에 기반한 마일스톤 정의입니다.
/// 동일 공간의 반복 방문으로 중복 획득하지 않도록 서로 다른 museum_id 수를 기준으로 합니다.
const _milestoneDefinitions = <BadgeDefinition>[
  BadgeDefinition(
    id: 'milestone-first-step',
    title: '첫 발걸음',
    description: '서로 다른 문화공간 1곳을 방문하세요.',
    category: BadgeCategory.milestone,
    target: 1,
    visualKey: 'first-step',
  ),
  BadgeDefinition(
    id: 'milestone-cultural-walker',
    title: '문화 산책자',
    description: '서로 다른 문화공간 3곳을 방문하세요.',
    category: BadgeCategory.milestone,
    target: 3,
    visualKey: 'cultural-walker',
  ),
  BadgeDefinition(
    id: 'milestone-cultural-explorer',
    title: '문화 탐험가',
    description: '서로 다른 문화공간 5곳을 방문하세요.',
    category: BadgeCategory.milestone,
    target: 5,
    visualKey: 'cultural-explorer',
  ),
  BadgeDefinition(
    id: 'milestone-cultural-traveler',
    title: '문화 여행자',
    description: '서로 다른 문화공간 10곳을 방문하세요.',
    category: BadgeCategory.milestone,
    target: 10,
    visualKey: 'cultural-traveler',
  ),
];

/// 운영자가 Production DB에서 확인한 is_active=true 국립박물관 레코드를 사용합니다.
/// legacyMuseumIds에는 동일 박물관으로 확인된 과거 inactive UUID만 명시적으로 넣습니다.
const _nationalMuseumDefinitions = <BadgeDefinition>[
  BadgeDefinition(
    id: 'national-museum-central',
    title: '국립중앙박물관',
    description: '국립중앙박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: 'e3ef47f5-3e16-40a5-bbcb-48faf50e6fc0',
    legacyMuseumIds: [
      'f254335a-c56c-4c91-8886-799b8841c5c4',
      'a5637e84-bdc9-417c-9737-6de2aa75af7d',
    ],
    visualKey: 'central',
  ),
  BadgeDefinition(
    id: 'national-museum-gyeongju',
    title: '국립경주박물관',
    description: '국립경주박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: '90d6e56e-d41d-4ee6-96fc-be835da2ab1a',
    legacyMuseumIds: ['d7ba7be8-0d20-44da-82fd-733303f4f244'],
    visualKey: 'gyeongju',
  ),
  BadgeDefinition(
    id: 'national-museum-buyeo',
    title: '국립부여박물관',
    description: '국립부여박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: '004c517c-0ee3-49aa-842c-bedb2bed8b5a',
    visualKey: 'buyeo',
  ),
  BadgeDefinition(
    id: 'national-museum-gongju',
    title: '국립공주박물관',
    description: '국립공주박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: '4168ce4e-bf40-485f-b68d-3487e7444f18',
    visualKey: 'gongju',
  ),
  BadgeDefinition(
    id: 'national-museum-gwangju',
    title: '국립광주박물관',
    description: '국립광주박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: 'b65f27c9-857e-4c37-8361-8b077871d881',
    legacyMuseumIds: ['7d0cb6ec-a19e-4d2a-bee5-3c3fecd58a3c'],
    visualKey: 'gwangju',
  ),
  BadgeDefinition(
    id: 'national-museum-jeonju',
    title: '국립전주박물관',
    description: '국립전주박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: '0160d1af-ae1c-40ee-b45b-44bc4f52b2a5',
    legacyMuseumIds: ['b8575991-1e46-4d4b-965d-d42c50ce88ec'],
    visualKey: 'jeonju',
  ),
  BadgeDefinition(
    id: 'national-museum-jinju',
    title: '국립진주박물관',
    description: '국립진주박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: '88d7f578-a91d-48c5-9ed6-c4c698fdcf36',
    legacyMuseumIds: [
      '502055dc-094a-450b-80b5-f70f03550497',
      '29591424-2b3f-4c3f-878f-811d48035728',
    ],
    visualKey: 'jinju',
  ),
  BadgeDefinition(
    id: 'national-museum-jeju',
    title: '국립제주박물관',
    description: '국립제주박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: '84c6d323-a061-4601-95bd-a7d55f5ef917',
    legacyMuseumIds: [
      '182d997d-f20b-436c-82a0-2471b4017c97',
      '2a569509-6474-4c63-badb-f1c0d028dc6f',
    ],
    visualKey: 'jeju',
  ),
  BadgeDefinition(
    id: 'national-museum-gimhae',
    title: '국립김해박물관',
    description: '국립김해박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: '08f1e955-a10d-4004-9242-79b05417b6ce',
    visualKey: 'gimhae',
  ),
  BadgeDefinition(
    id: 'national-museum-cheongju',
    title: '국립청주박물관',
    description: '국립청주박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: 'c8ce2fc8-03d6-484e-9449-20bf95bf4415',
    visualKey: 'cheongju',
  ),
  BadgeDefinition(
    id: 'national-museum-daegu',
    title: '국립대구박물관',
    description: '국립대구박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: '854d8662-cc9e-4b04-8299-4fde9cb42c4d',
    legacyMuseumIds: [
      '1c27831c-fe2c-45ac-add3-55ba3c8eeda3',
      'ed6511f9-51f4-4621-942b-f765f1f3158b',
    ],
    visualKey: 'daegu',
  ),
  BadgeDefinition(
    id: 'national-museum-chuncheon',
    title: '국립춘천박물관',
    description: '국립춘천박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: '22273383-459a-429d-9893-a364a98e25df',
    visualKey: 'chuncheon',
  ),
  BadgeDefinition(
    id: 'national-museum-naju',
    title: '국립나주박물관',
    description: '국립나주박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: '2f4a36d2-2342-4d99-a55d-65da5e369607',
    legacyMuseumIds: ['33bfe263-ad6f-49bc-969c-74db81c8d1f9'],
    visualKey: 'naju',
  ),
  BadgeDefinition(
    id: 'national-museum-iksan',
    title: '국립익산박물관',
    description: '국립익산박물관을 방문하면 획득할 수 있어요.',
    category: BadgeCategory.nationalMuseum,
    target: 1,
    museumId: 'aca1194e-4fa0-426c-b328-6d23392a7d2b',
    visualKey: 'iksan',
  ),
];

/// 별도 DB fetch 없이 이미 로드된 내 방문 기록으로 Badge 상태를 계산합니다.
/// myVisitsProvider의 loading/error 상태도 그대로 전파해 실패를 빈 컬렉션으로 처리하지 않습니다.
final badgeCollectionProvider =
    Provider<AsyncValue<BadgeCollectionState>>((ref) {
  final visitsAsync = ref.watch(myVisitsProvider);

  return visitsAsync.whenData((visits) {
    final visitedMuseumIds = visits.map((visit) => visit.museumId).toSet();
    final distinctMuseumCount = visitedMuseumIds.length;

    return BadgeCollectionState(
      milestones: [
        for (final definition in _milestoneDefinitions)
          BadgeProgress(definition: definition, current: distinctMuseumCount),
      ],
      nationalMuseums: [
        for (final definition in _nationalMuseumDefinitions)
          BadgeProgress(
            definition: definition,
            current: visitedMuseumIds
                    .intersection(definition.validMuseumIds)
                    .isNotEmpty
                ? 1
                : 0,
          ),
      ],
    );
  });
});
