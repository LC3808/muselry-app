# Build Notes — M1-M4 Launch Hardening

## 기본 정보

| 항목 | 내용 |
|---|---|
| 브랜치 | `feature/launch-hardening` |
| Commit Hash | `9a4e648` |
| 작업 일시 | 2026-06-10 |
| flutter analyze | **No issues found** |
| APK 빌드 | 이번 사이클 미포함 (운영자 담당) |

---

## 변경 파일 목록

| 파일 | 변경 내용 |
|---|---|
| `lib/presentation/widgets/common/main_scaffold.dart` | M1: PopScope 추가, Android 백키 UX 정상화 |
| `lib/presentation/screens/explore/explore_screen.dart` | M1: per-screen PopScope 제거 / M3: _SortChipBar 추가 |
| `lib/presentation/screens/visit/visit_history_screen.dart` | M1: per-screen PopScope 제거 |
| `lib/presentation/screens/community/community_screen.dart` | M1: per-screen PopScope 제거 |
| `lib/presentation/widgets/museum/museum_image.dart` | M2: kids_category=dedicated 우선 fallback |
| `lib/presentation/widgets/museum/museum_card.dart` | M2: MuseumImage kidsCategory 전달 |
| `lib/presentation/screens/detail/museum_detail_screen.dart` | M2: MuseumImage 적용, _ImagePlaceholder 제거 |
| `lib/domain/models/museum.dart` | M3: bayesianScore 필드 추가 |
| `lib/presentation/providers/museum_provider.dart` | M3: SortOrder enum + setSortOrder |
| `lib/data/repositories/museum_repository.dart` | M3: sortOrder 정렬 / M4: searchForMap() |
| `lib/presentation/screens/map/map_screen.dart` | M4: 지도 내 검색바 + 결과 핀 + 패널 |

---

## M1: 뒤로가기 UX 정상화

- **루트 탭** (홈/탐색/지도/기록/커뮤니티): `main_scaffold.dart`에 `PopScope` 통합
  - 홈 탭이 아닌 탭에서 백키 → 홈 탭으로 이동
  - 홈 탭에서 백키 → 스낵바 표시 ("한 번 더 누르면 앱이 종료됩니다"), 2초 내 재입력 시 `SystemNavigator.pop()`
- **하위 화면** (상세/리뷰/방문기록 등): go_router 자동 백버튼 그대로 동작

## M2: 썸네일 fallback 위젯

- `museum_image.dart`: `kids_category=dedicated` → 어린이 전용 플레이스홀더 우선, 이후 type별 이모지 fallback
- `museum_card.dart`, `museum_detail_screen.dart`: `MuseumImage` 위젯 통일 적용
- `museum_detail_screen.dart`: 기존 `_ImagePlaceholder` 클래스 제거

## M3: 정렬 UI + bayesian_score 랭킹

- `SortOrder` enum: `relevance` / `distance` / `popularity` / `rating`
- 탐색 화면 상단에 `_SortChipBar` (가로 스크롤 칩 4종)
- repository: `sortOrder` 파라미터 추가
  - `rating` → `bayesian_score DESC, review_count DESC`
  - `popularity` → `static_popularity_rank ASC`
  - `distance` → name ASC fallback (PostgREST 거리 정렬 미지원)
- `museum.dart`: `bayesianScore` 필드 추가 (DB 컬럼: `bayesian_score`)

> **운영자 후속 작업 필요**: `museums` 테이블에 `bayesian_score` 컬럼 추가 및 값 계산 (아래 SQL DDL 참고)

## M4: 지도 탭 내 검색

- `_MapSearchBar`: 실제 검색 기능 (400ms 디바운스), 탐색 화면 이탈 제거
- `searchForMap()`: 좌표 있는 박물관만 검색, 최대 50건
- `_SearchResultPanel`: 상위 5건 목록 표시, 위치 이동 버튼 포함
- 검색 초기화 시 전체 마커 복원

---

## 운영자 후속 작업 (SQL DDL)

### bayesian_score 컬럼 추가

```sql
-- museums 테이블에 bayesian_score 컬럼 추가
ALTER TABLE museums
  ADD COLUMN IF NOT EXISTS bayesian_score DOUBLE PRECISION;

-- Bayesian 보정 별점 계산 (전체 평균 + 최소 리뷰 수 기준)
-- C = 전체 평균 별점, m = 최소 리뷰 수 기준 (예: 5)
WITH stats AS (
  SELECT
    AVG(average_rating) AS global_mean,
    5 AS min_votes
  FROM museums
  WHERE review_count > 0
)
UPDATE museums m
SET bayesian_score = (
  (s.min_votes * s.global_mean + COALESCE(m.review_count, 0) * COALESCE(m.average_rating, 0))
  / (s.min_votes + COALESCE(m.review_count, 0))
)
FROM stats s
WHERE m.is_active = true;

-- 인덱스 추가 (정렬 성능)
CREATE INDEX IF NOT EXISTS idx_museums_bayesian_score
  ON museums (bayesian_score DESC NULLS LAST);
```

---

## 다음 사이클 (M5~M6) 선행 조건

M5~M6 작업 시작 전 운영자가 아래 SQL을 Supabase Dashboard에서 실행해야 합니다.

### M5: 커뮤니티 댓글 테이블

```sql
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 500),
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS 활성화
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- 정책: 전체 읽기
CREATE POLICY "comments_select_all"
  ON comments FOR SELECT
  USING (is_deleted = false);

-- 정책: 본인만 작성
CREATE POLICY "comments_insert_own"
  ON comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 정책: 본인만 수정
CREATE POLICY "comments_update_own"
  ON comments FOR UPDATE
  USING (auth.uid() = user_id);

-- 정책: 본인만 삭제 (soft delete)
CREATE POLICY "comments_delete_own"
  ON comments FOR DELETE
  USING (auth.uid() = user_id);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_comments_review_id ON comments (review_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments (user_id);

-- 댓글 알림 테이블 (인앱 알림)
CREATE TABLE IF NOT EXISTS comment_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  review_id UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE comment_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comment_notifications_own"
  ON comment_notifications FOR ALL
  USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_comment_notifications_user_id
  ON comment_notifications (user_id, is_read);
```

### M6: 문의/건의 테이블

```sql
CREATE TABLE IF NOT EXISTS feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  category TEXT NOT NULL CHECK (category IN ('bug', 'suggestion', 'inquiry', 'other')),
  title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 100),
  content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 2000),
  contact_email TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_review', 'resolved')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- 정책: 본인 피드백만 읽기
CREATE POLICY "feedback_select_own"
  ON feedback FOR SELECT
  USING (auth.uid() = user_id);

-- 정책: 인증된 사용자만 작성
CREATE POLICY "feedback_insert_auth"
  ON feedback FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_feedback_user_id ON feedback (user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback (status);
```

---

## 보류 항목

- **M5 커뮤니티 댓글 CRUD**: 운영자 SQL 적용 후 이어서 작업
- **M6 문의/건의 폼**: 운영자 SQL 적용 후 이어서 작업
- **M7 마이페이지 재구성 + 레벨 뱃지**: 출시 포함 확정 후 착수
