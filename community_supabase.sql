-- ============================================================
-- choible community tables
-- Supabase SQL Editor에서 실행해주세요
-- 이전에 실행했어도 다시 실행해도 안전합니다 (IF NOT EXISTS 사용)
-- ============================================================

-- 1. community_posts
CREATE TABLE IF NOT EXISTS community_posts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  user_email text,
  user_nickname text,
  title text NOT NULL,
  places text[] DEFAULT '{}',
  emoji text DEFAULT '✈️',
  description text,
  likes_count integer DEFAULT 0 NOT NULL,
  comments_count integer DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- 2. community_likes
CREATE TABLE IF NOT EXISTS community_likes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id uuid REFERENCES community_posts(id) ON DELETE CASCADE NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(post_id, user_id)
);

-- 3. community_comments
CREATE TABLE IF NOT EXISTS community_comments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id uuid REFERENCES community_posts(id) ON DELETE CASCADE NOT NULL,
  user_id uuid NOT NULL,
  user_email text,
  user_nickname text,
  content text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- ============================================================
-- 권한 부여 (GRANT) ← 이게 없으면 permission denied 발생!
-- ============================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON community_posts TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON community_likes TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON community_comments TO anon, authenticated;

-- ============================================================
-- RLS (Row Level Security)
-- ============================================================

ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 후 재생성 (중복 오류 방지)
DROP POLICY IF EXISTS "posts_read_all" ON community_posts;
DROP POLICY IF EXISTS "posts_insert_auth" ON community_posts;
DROP POLICY IF EXISTS "posts_update_own" ON community_posts;
DROP POLICY IF EXISTS "posts_delete_own" ON community_posts;
DROP POLICY IF EXISTS "likes_read_all" ON community_likes;
DROP POLICY IF EXISTS "likes_insert_auth" ON community_likes;
DROP POLICY IF EXISTS "likes_delete_own" ON community_likes;
DROP POLICY IF EXISTS "comments_read_all" ON community_comments;
DROP POLICY IF EXISTS "comments_insert_auth" ON community_comments;
DROP POLICY IF EXISTS "comments_delete_own" ON community_comments;

-- community_posts 정책
CREATE POLICY "posts_read_all"    ON community_posts FOR SELECT USING (true);
CREATE POLICY "posts_insert_auth" ON community_posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "posts_update_own"  ON community_posts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "posts_delete_own"  ON community_posts FOR DELETE USING (auth.uid() = user_id);

-- community_likes 정책
CREATE POLICY "likes_read_all"    ON community_likes FOR SELECT USING (true);
CREATE POLICY "likes_insert_auth" ON community_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "likes_delete_own"  ON community_likes FOR DELETE USING (auth.uid() = user_id);

-- community_comments 정책
CREATE POLICY "comments_read_all"    ON community_comments FOR SELECT USING (true);
CREATE POLICY "comments_insert_auth" ON community_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "comments_delete_own"  ON community_comments FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- RPC functions (좋아요·댓글 카운트 원자적 업데이트)
-- ============================================================

CREATE OR REPLACE FUNCTION increment_likes(pid uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE community_posts SET likes_count = likes_count + 1 WHERE id = pid;
$$;

CREATE OR REPLACE FUNCTION decrement_likes(pid uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE community_posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = pid;
$$;

CREATE OR REPLACE FUNCTION increment_comments(pid uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = pid;
$$;

CREATE OR REPLACE FUNCTION decrement_comments(pid uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE community_posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = pid;
$$;

-- RPC 권한
GRANT EXECUTE ON FUNCTION increment_likes TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_likes TO authenticated;
GRANT EXECUTE ON FUNCTION increment_comments TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_comments TO authenticated;

-- ============================================================
-- 인덱스
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_community_posts_created_at ON community_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_likes_post_id ON community_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_community_likes_user_id ON community_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_community_comments_post_id ON community_comments(post_id);
