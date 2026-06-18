-- ==============================================================================
-- 핫픽스: 이메일 가입 트리거 경합 해결
-- 적용일: 2026-06-15
-- 원인:
--   1. handle_new_user — nickname null/UNIQUE 충돌 (이메일 prefix 소스 누락)
--   2. handle_new_user_email (on_auth_user_email_sync) — 신규 INSERT 시
--      nickname 없이 profiles INSERT 시도 → NOT NULL 위반 → 가입 실패
-- 수정:
--   1. handle_new_user: nickname COALESCE(소셜>이메일prefix>fallback) +
--      UNIQUE 충돌 시 suffix 재시도 (LOOP 방식)
--   2. handle_new_user_email: INSERT 제거, UPDATE 전용으로 변경
--   3. on_auth_user_email_sync 트리거: AFTER UPDATE OF email 로 한정
--      (신규 INSERT 시 미작동)
-- 멱등성: CREATE OR REPLACE + DROP TRIGGER IF EXISTS 구조
-- ==============================================================================


-- ============================================================
-- 1. handle_new_user 함수 수정
--    nickname COALESCE(소셜>이메일prefix>fallback) + UNIQUE 충돌 시 suffix 재시도
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  _nickname TEXT;
  _email    TEXT;
  _avatar   TEXT;
  _suffix   INT := 0;
  _candidate TEXT;
BEGIN
  -- 닉네임 기본값 결정 (우선순위: 소셜 메타 > 이메일 prefix > fallback)
  _nickname := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'nickname'), ''),
    NULLIF(TRIM(SPLIT_PART(NEW.email, '@', 1)), ''),
    'user_' || SUBSTR(NEW.id::text, 1, 8)
  );

  -- 이메일 (카카오 미동의 시 NULL 허용)
  _email := NEW.email;

  -- 아바타
  _avatar := COALESCE(
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.raw_user_meta_data->>'picture'
  );

  -- UNIQUE 충돌 시 suffix 재시도 (최대 10회)
  LOOP
    _candidate := CASE WHEN _suffix = 0 THEN _nickname
                       ELSE _nickname || '_' || _suffix
                  END;

    BEGIN
      INSERT INTO public.profiles (id, nickname, email, avatar_url)
      VALUES (NEW.id, _candidate, _email, _avatar)
      ON CONFLICT (id) DO NOTHING;
      EXIT; -- 성공 시 루프 종료
    EXCEPTION WHEN unique_violation THEN
      _suffix := _suffix + 1;
      IF _suffix > 10 THEN
        -- 최대 재시도 초과 시 uuid 기반 fallback
        _nickname := 'user_' || SUBSTR(NEW.id::text, 1, 8);
        _suffix := 0;
      END IF;
    END;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 재등록
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- 2. handle_new_user_email 함수 수정
--    INSERT 제거 → UPDATE 전용 (신규 가입 시 nickname null 충돌 방지)
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user_email()
RETURNS TRIGGER AS $$
BEGIN
  -- 이메일 변경(UPDATE) 시에만 profiles.email 동기화
  -- INSERT 시에는 handle_new_user가 담당하므로 여기서는 처리하지 않음
  UPDATE public.profiles
  SET email = NEW.email,
      updated_at = NOW()
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- on_auth_user_email_sync 트리거: AFTER UPDATE OF email 로 한정 (INSERT 제외)
DROP TRIGGER IF EXISTS on_auth_user_email_sync ON auth.users;
CREATE TRIGGER on_auth_user_email_sync
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW
  WHEN (NEW.email IS DISTINCT FROM OLD.email)
  EXECUTE FUNCTION public.handle_new_user_email();


-- ============================================================
-- 검증 쿼리 (실행 후 확인)
-- ============================================================
-- -- 트리거 등록 확인
-- SELECT trigger_name, event_manipulation, event_object_schema, event_object_table
-- FROM information_schema.triggers
-- WHERE trigger_name IN ('on_auth_user_created', 'on_auth_user_email_sync')
-- ORDER BY trigger_name, event_manipulation;
--
-- 기대 결과:
-- on_auth_user_created  | INSERT | auth | users
-- on_auth_user_email_sync | UPDATE | auth | users
--
-- -- profiles 없는 auth.users 확인 (가입 실패 사용자)
-- SELECT u.id, u.email, u.created_at
-- FROM auth.users u
-- LEFT JOIN public.profiles p ON p.id = u.id
-- WHERE p.id IS NULL;
