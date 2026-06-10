# Build Notes — Launch Hardening (M1~M6)

## 기본 정보

| 항목 | 내용 |
|---|---|
| 브랜치 | `feature/launch-hardening` |
| M1~M4 커밋 | `9a4e648` |
| M5~M6 커밋 | `1b6dfd4` |
| 작업 일시 | 2026-06-10 |
| flutter analyze | **No issues found** |
| APK 빌드 | 이번 사이클 미포함 (운영자 담당) |

---

## 변경 파일 목록

### M1~M4 (커밋 9a4e648)

| 파일 | 변경 내용 |
|---|---|
| `lib/presentation/widgets/common/main_scaffold.dart` | M1: PopScope 통합, Android 백키 UX 정상화 |
| `lib/presentation/screens/explore/explore_screen.dart` | M1: per-screen PopScope 제거 / M3: _SortChipBar 추가 |
| `lib/presentation/screens/visit/visit_history_screen.dart` | M1: per-screen PopScope 제거 |
| `lib/presentation/screens/community/community_screen.dart` | M1: per-screen PopScope 제거 (→ M5에서 전면 재작성) |
| `lib/presentation/widgets/museum/museum_image.dart` | M2: kids_category=dedicated 우선 fallback |
| `lib/presentation/widgets/museum/museum_card.dart` | M2: MuseumImage kidsCategory 전달 |
| `lib/presentation/screens/detail/museum_detail_screen.dart` | M2: MuseumImage 적용, _ImagePlaceholder 제거 |
| `lib/domain/models/museum.dart` | M3: bayesianScore 필드 추가 |
| `lib/presentation/providers/museum_provider.dart` | M3: SortOrder enum + setSortOrder |
| `lib/data/repositories/museum_repository.dart` | M3: sortOrder 정렬 / M4: searchForMap() |
| `lib/presentation/screens/map/map_screen.dart` | M4: 지도 내 검색바 + 결과 핀 + 패널 |

### M5~M6 (커밋 1b6dfd4)

| 파일 | 변경 내용 |
|---|---|
| `lib/domain/models/comment.dart` | 신규: Comment 모델 (status 방식) |
| `lib/domain/models/app_notification.dart` | 신규: AppNotification 모델 |
| `lib/domain/models/feedback_item.dart` | 신규: FeedbackItem 모델 (data_error 포함) |
| `lib/data/repositories/comment_repository.dart` | 신규: 댓글 CRUD + 알림 조회/읽음 처리 |
| `lib/data/repositories/feedback_repository.dart` | 신규: feedback 테이블 INSERT |
| `lib/presentation/providers/comment_provider.dart` | 신규: CommentListNotifier + NotificationNotifier |
| `lib/presentation/screens/notification/notification_screen.dart` | 신규: 인앱 알림 목록 화면 |
| `lib/presentation/screens/feedback/feedback_screen.dart` | 신규: 문의/건의 폼 화면 |
| `lib/presentation/screens/community/community_screen.dart` | M5: 댓글 섹션 + 알림 뱃지 추가 |
| `lib/presentation/screens/mypage/mypage_screen.dart` | M5: 알림 뱃지 / M6: 문의/건의 진입점 |
| `lib/config/router.dart` | /notifications, /feedback 라우트 추가 |

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

## M4: 지도 탭 내 검색

- `_MapSearchBar`: 실제 검색 기능 (400ms 디바운스), 탐색 화면 이탈 제거
- `searchForMap()`: 좌표 있는 박물관만 검색, 최대 50건
- `_SearchResultPanel`: 상위 5건 목록 표시, 위치 이동 버튼 포함
- 검색 초기화 시 전체 마커 복원

## M5: 댓글 CRUD + 인앱 알림

- 댓글 상태: `status IN ('published','hidden','removed')` (소프트 삭제, 리뷰 패턴 일관)
- 알림 row: DB 트리거 `notify_review_author_on_comment` 자동 생성 — **앱 직접 INSERT 금지**
- 앱: `notifications` 테이블 조회 + `is_read` UPDATE만 수행
- 알림 뱃지: 마이페이지 + 커뮤니티 앱바에 빨간 점 표시 (MVP)
- 커뮤니티 화면: 리뷰 카드 하단 댓글 토글 → 댓글 목록 + 입력창

## M6: 문의/건의 폼

- 카테고리: `bug`(버그 신고) / `suggestion`(기능 건의) / `data_error`(데이터 오류) / `other`(기타)
- 내용 최소 10자 ~ 최대 1000자
- 마이페이지 내 활동 섹션 하단에 진입점 추가
- 제출 성공 시 스낵바 표시 후 화면 닫기

---

## 운영자 후속 작업 (SQL DDL)

### 1. bayesian_score 컬럼 (M3)

```sql
ALTER TABLE museums
  ADD COLUMN IF NOT EXISTS bayesian_score DOUBLE PRECISION;

WITH stats AS (
  SELECT AVG(average_rating) AS global_mean, 5 AS min_votes
  FROM museums WHERE review_count > 0
)
UPDATE museums m
SET bayesian_score = (
  (s.min_votes * s.global_mean + COALESCE(m.review_count, 0) * COALESCE(m.average_rating, 0))
  / (s.min_votes + COALESCE(m.review_count, 0))
)
FROM stats s WHERE m.is_active = true;

CREATE INDEX IF NOT EXISTS idx_museums_bayesian_score
  ON museums (bayesian_score DESC NULLS LAST);
```

### 2. comments 테이블 + RLS + 트리거 (M5)

```sql
-- comments 테이블
CREATE TABLE IF NOT EXISTS comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id   UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content     TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 500),
  status      TEXT NOT NULL DEFAULT 'published'
                CHECK (status IN ('published','hidden','removed')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comments_review_id
  ON comments (review_id, status, created_at);

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_comments_updated_at
  BEFORE UPDATE ON comments
  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

-- RLS
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comments_select_published" ON comments
  FOR SELECT USING (status = 'published');

CREATE POLICY "comments_insert_own" ON comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "comments_update_own" ON comments
  FOR UPDATE USING (auth.uid() = user_id);
```

### 3. notifications 테이블 + RLS + 트리거 (M5)

```sql
-- notifications 테이블
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL DEFAULT 'comment',
  comment_id  UUID REFERENCES comments(id) ON DELETE SET NULL,
  review_id   UUID REFERENCES reviews(id) ON DELETE SET NULL,
  is_read     BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications (user_id, is_read, created_at DESC);

-- RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select_own" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "notifications_update_own" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- 댓글 작성 시 리뷰 작성자에게 알림 자동 생성
CREATE OR REPLACE FUNCTION notify_review_author_on_comment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_review_author_id UUID;
BEGIN
  SELECT user_id INTO v_review_author_id
  FROM reviews WHERE id = NEW.review_id;

  -- 본인 댓글에는 알림 생성 안 함
  IF v_review_author_id IS NOT NULL
     AND v_review_author_id <> NEW.user_id THEN
    INSERT INTO notifications (user_id, type, comment_id, review_id)
    VALUES (v_review_author_id, 'comment', NEW.id, NEW.review_id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_on_comment
  AFTER INSERT ON comments
  FOR EACH ROW EXECUTE FUNCTION notify_review_author_on_comment();
```

### 4. feedback 테이블 + RLS (M6)

```sql
CREATE TABLE IF NOT EXISTS feedback (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category    TEXT NOT NULL
                CHECK (category IN ('bug','suggestion','data_error','other')),
  content     TEXT NOT NULL CHECK (char_length(content) BETWEEN 10 AND 1000),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feedback_insert_own" ON feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "feedback_select_own" ON feedback
  FOR SELECT USING (auth.uid() = user_id);
```

---

## 보류 항목

| 항목 | 사유 |
|---|---|
| M7 마이페이지 재구성 + 레벨 뱃지 | 출시 포함 확정 후 착수 |
| 댓글 푸시 알림 | 출시 후 (인앱 알림만 MVP) |
| 내가 쓴 리뷰 화면 | 준비 중 배지 유지 |
