-- ==============================================================================
-- 뮤즐리(Museuly) Supabase PostgreSQL 스키마 및 RLS 정책 설계 초안 (Day 1)
-- ==============================================================================

-- 1. 확장 기능 활성화
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis"; -- 지도 검색(거리 계산)을 위한 확장 (향후 활용)

-- ==============================================================================
-- 2. 테이블 생성
-- ==============================================================================

-- 2.1 profiles 테이블 (사용자 프로필)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  nickname TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'museum_owner', 'admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.2 museums 테이블 (박물관 기본 정보 - 공공데이터 적재용)
CREATE TABLE public.museums (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  external_id TEXT UNIQUE, -- 공공데이터 원본 고유번호
  name TEXT NOT NULL,
  type TEXT NOT NULL, -- 박물관, 미술관, 기념관 등
  region_1 TEXT NOT NULL, -- 시/도
  region_2 TEXT NOT NULL, -- 시/군/구
  address TEXT NOT NULL,
  road_address TEXT,
  latitude NUMERIC(10, 7) NOT NULL,
  longitude NUMERIC(10, 7) NOT NULL,
  phone TEXT,
  homepage_url TEXT,
  opening_hours TEXT,
  closed_days TEXT,
  admission_fee TEXT,
  description TEXT,
  image_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.3 bookmarks 테이블 (가고 싶은 곳)
CREATE TABLE public.bookmarks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  museum_id UUID REFERENCES public.museums(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, museum_id) -- 한 사용자가 같은 박물관을 중복 북마크 방지
);

-- 2.4 visits 테이블 (방문 기록 및 개인 메모 통합)
CREATE TABLE public.visits (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  museum_id UUID REFERENCES public.museums(id) ON DELETE CASCADE NOT NULL,
  visited_at DATE NOT NULL,
  companion_type TEXT,
  rating NUMERIC(2, 1) CHECK (rating >= 1 AND rating <= 5),
  private_note TEXT, -- 본인만 열람 가능한 메모
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.5 reviews 테이블 (공개 리뷰)
CREATE TABLE public.reviews (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  museum_id UUID REFERENCES public.museums(id) ON DELETE CASCADE NOT NULL,
  visit_id UUID REFERENCES public.visits(id) ON DELETE SET NULL, -- 연관된 방문 기록
  rating NUMERIC(2, 1) NOT NULL CHECK (rating >= 1 AND rating <= 5),
  content TEXT NOT NULL,
  image_urls TEXT[], -- Supabase Storage URL 배열
  status TEXT DEFAULT 'published' CHECK (status IN ('published', 'hidden', 'deleted')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==============================================================================
-- 3. Row Level Security (RLS) 정책
-- ==============================================================================

-- RLS 활성화
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.museums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- 3.1 profiles 정책
-- 누구나 프로필 조회 가능 (리뷰 작성자 정보 표시용)
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
-- 본인 프로필만 수정 가능
CREATE POLICY "Users can update own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);
-- 가입 시 자동 생성을 위한 insert (trigger를 통한 생성 권장)
CREATE POLICY "Users can insert their own profile." ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- 3.2 museums 정책
-- 누구나 활성화된 박물관 정보 조회 가능
CREATE POLICY "Museums are viewable by everyone." ON public.museums FOR SELECT USING (is_active = true);
-- 수정/삭제는 admin만 가능 (MVP 기준)
CREATE POLICY "Only admins can insert museums." ON public.museums FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Only admins can update museums." ON public.museums FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- 3.3 bookmarks 정책
-- 본인의 북마크만 조회 가능
CREATE POLICY "Users can view own bookmarks." ON public.bookmarks FOR SELECT USING (auth.uid() = user_id);
-- 본인의 북마크만 생성/삭제 가능
CREATE POLICY "Users can insert own bookmarks." ON public.bookmarks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own bookmarks." ON public.bookmarks FOR DELETE USING (auth.uid() = user_id);

-- 3.4 visits 정책 (개인 메모 포함이므로 보안 중요)
-- 본인의 방문 기록(메모 포함)만 조회 가능
CREATE POLICY "Users can view own visits." ON public.visits FOR SELECT USING (auth.uid() = user_id);
-- 본인의 방문 기록만 생성/수정/삭제 가능
CREATE POLICY "Users can insert own visits." ON public.visits FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own visits." ON public.visits FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own visits." ON public.visits FOR DELETE USING (auth.uid() = user_id);

-- 3.5 reviews 정책
-- 누구나 published 상태의 리뷰 조회 가능
CREATE POLICY "Published reviews are viewable by everyone." ON public.reviews FOR SELECT USING (status = 'published');
-- 본인의 리뷰는 상태 상관없이 조회 가능
CREATE POLICY "Users can view own reviews regardless of status." ON public.reviews FOR SELECT USING (auth.uid() = user_id);
-- 본인의 리뷰만 생성/수정/삭제 가능
CREATE POLICY "Users can insert own reviews." ON public.reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own reviews." ON public.reviews FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own reviews." ON public.reviews FOR DELETE USING (auth.uid() = user_id);

-- ==============================================================================
-- 4. Auth Trigger (회원가입 시 프로필 자동 생성)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, nickname, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'user_' || substr(NEW.id::text, 1, 8)),
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
