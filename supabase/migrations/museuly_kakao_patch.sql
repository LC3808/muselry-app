-- ==============================================================================
-- 뮤즐리 카카오 로그인 지원 패치 (Day 2)
-- Supabase SQL Editor에서 실행하세요.
-- ==============================================================================
-- [2026-06-15 수정] 컬럼 순서 오류 수정:
--   VALUES (_nickname, _email, _avatar, NEW.id) → VALUES (NEW.id, _nickname, _email, _avatar)
--   이메일 가입 닉네임 소스 누락 수정: SPLIT_PART(email,'@',1) 추가
--   최신 확정 버전은 hotfix_email_signup_trigger.sql 참조
-- ==============================================================================

-- 1. profiles 테이블에 email 컬럼 추가 (nullable)
--    카카오 유저는 이메일 동의를 안 할 수 있으므로 nullable로 설계
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email TEXT;

-- 2. handle_new_user Trigger 함수 수정
--    - 카카오 로그인 시 nickname: 카카오 닉네임 → 없으면 이메일 prefix → user_XXXXXXXX
--    - 카카오 로그인 시 email: 카카오 이메일 → 없으면 NULL (허용)
--    - avatar_url: 카카오 프로필 이미지 URL 자동 세팅
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  _nickname TEXT;
  _email    TEXT;
  _avatar   TEXT;
BEGIN
  -- 닉네임: raw_user_meta_data.full_name > name > nickname > 이메일 prefix > fallback
  _nickname := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'nickname'), ''),
    NULLIF(TRIM(SPLIT_PART(NEW.email, '@', 1)), ''),
    'user_' || SUBSTR(NEW.id::text, 1, 8)
  );

  -- 이메일: auth.users.email (카카오 동의 시 존재, 미동의 시 NULL)
  _email := NEW.email;

  -- 아바타: raw_user_meta_data.avatar_url > picture
  _avatar := COALESCE(
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.raw_user_meta_data->>'picture'
  );

  -- [수정] 컬럼 순서와 값 순서 일치 (기존 코드의 순서 오류 수정)
  INSERT INTO public.profiles (id, nickname, email, avatar_url)
  VALUES (NEW.id, _nickname, _email, _avatar)
  ON CONFLICT (id) DO NOTHING;  -- 중복 삽입 방지 (소셜 로그인 재시도 시)

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger 재등록 (함수 교체 후 재연결)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 4. 확인 쿼리 (실행 후 아래로 결과 확인)
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'profiles'
-- ORDER BY ordinal_position;
