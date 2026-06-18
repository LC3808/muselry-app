-- ============================================================
-- Day 10: profiles 자동 생성 트리거 (A안)
-- ============================================================
-- 목적: 신규 유저 가입(이메일/Kakao/Google/Apple) 시
--       public.profiles 테이블에 row를 자동 생성합니다.
--
-- 배경: handle_new_user 트리거가 마이그레이션 파일에 없어
--       Supabase 대시보드에서 수동 등록 여부가 불확실합니다.
--       이 파일을 실행하면 트리거를 명시적으로 재등록합니다.
--
-- 멱등성: CREATE OR REPLACE + DROP TRIGGER IF EXISTS 구조로
--         중복 실행해도 안전합니다.
--
-- [2026-06-15 수정] 이메일 가입 시 nickname 소스 누락 수정:
--   SPLIT_PART(email,'@',1) 추가, email 컬럼 포함
--   최신 확정 버전은 hotfix_email_signup_trigger.sql 참조
-- ============================================================

-- 1) 트리거 함수 생성/교체
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, nickname, email, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(
      NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
      NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
      NULLIF(TRIM(NEW.raw_user_meta_data->>'nickname'), ''),
      NULLIF(TRIM(SPLIT_PART(NEW.email, '@', 1)), ''),
      'user_' || SUBSTR(NEW.id::text, 1, 8)
    ),
    NEW.email,
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- 2) 기존 트리거 제거 후 재등록
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3) 검증 쿼리 (실행 후 확인)
-- SELECT trigger_name, event_manipulation, event_object_schema, event_object_table
-- FROM information_schema.triggers
-- WHERE trigger_name = 'on_auth_user_created';
--
-- 기대 결과:
-- trigger_name          | event_manipulation | event_object_schema | event_object_table
-- on_auth_user_created  | INSERT             | auth                | users
