-- ============================================
-- Running Coach App — Full DB Schema
-- Supabase SQL Editor에서 실행하세요
-- ============================================

-- 0. Helper: updated_at 자동 갱신 트리거 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 1. user_profiles (1:1 with auth.users)
-- ============================================
CREATE TABLE user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname varchar(50) NOT NULL,
  birth_year int,
  gender varchar(10),
  height_cm decimal(5,1),
  weight_kg decimal(5,1),
  running_experience varchar(20),
  preferred_distance varchar(20),
  weekly_available_days int,
  timezone varchar(50) DEFAULT 'Asia/Seoul',
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE TRIGGER set_updated_at_user_profiles
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 2. strava_connections (1:1 with user_profiles)
-- ============================================
CREATE TABLE strava_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES user_profiles(id) ON DELETE CASCADE,
  strava_athlete_id bigint NOT NULL,
  access_token text NOT NULL,
  refresh_token text NOT NULL,
  token_expires_at timestamptz NOT NULL,
  scope text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  last_sync_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE TRIGGER set_updated_at_strava_connections
  BEFORE UPDATE ON strava_connections
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 3. race_records (1:N with user_profiles)
-- ============================================
CREATE TABLE race_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  race_name varchar(100) NOT NULL,
  race_date date NOT NULL,
  distance_km decimal(6,2) NOT NULL,
  finish_time_seconds int NOT NULL,
  vdot_score decimal(4,1),
  memo text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE TRIGGER set_updated_at_race_records
  BEFORE UPDATE ON race_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 4. training_plans (1:N with user_profiles)
-- ============================================
CREATE TABLE training_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  plan_name varchar(100) NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'upcoming'
    CHECK (status IN ('active', 'upcoming', 'completed', 'cancelled')),
  goal_race_name varchar(100),
  goal_race_date date,
  goal_distance_km decimal(6,2) NOT NULL,
  goal_time_seconds int,
  vdot_score decimal(4,1),
  total_weeks int NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  training_days_per_week int NOT NULL,
  pace_zones jsonb,
  llm_context_snapshot jsonb,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE TRIGGER set_updated_at_training_plans
  BEFORE UPDATE ON training_plans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 5. training_weeks (1:N with training_plans)
-- ============================================
CREATE TABLE training_weeks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES training_plans(id) ON DELETE CASCADE,
  week_number int NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  phase varchar(20) NOT NULL
    CHECK (phase IN ('base', 'build', 'peak', 'taper')),
  target_distance_km decimal(6,1),
  weekly_summary text,
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(plan_id, week_number)
);

-- ============================================
-- 6. training_sessions (1:N with training_weeks)
-- ============================================
CREATE TABLE training_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_id uuid NOT NULL REFERENCES training_weeks(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES training_plans(id) ON DELETE CASCADE,
  session_date date NOT NULL,
  day_of_week int NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  session_type varchar(30) NOT NULL
    CHECK (session_type IN (
      'easy', 'marathon_pace', 'threshold', 'interval',
      'repetition', 'long_run', 'recovery', 'cross_training', 'rest'
    )),
  title varchar(100) NOT NULL,
  description text,
  target_distance_km decimal(5,1),
  target_duration_minutes int,
  target_pace varchar(20),
  workout_detail jsonb,
  status varchar(20) DEFAULT 'pending' NOT NULL
    CHECK (status IN ('pending', 'completed', 'skipped', 'partial')),
  completed_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE TRIGGER set_updated_at_training_sessions
  BEFORE UPDATE ON training_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 7. workout_logs (1:N with user_profiles)
-- ============================================
CREATE TABLE workout_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  session_id uuid REFERENCES training_sessions(id) ON DELETE SET NULL,
  source varchar(20) NOT NULL CHECK (source IN ('healthkit', 'strava')),
  external_id varchar(100),
  workout_date date NOT NULL,
  started_at timestamptz NOT NULL,
  ended_at timestamptz NOT NULL,
  distance_km decimal(6,2) NOT NULL,
  duration_seconds int NOT NULL,
  avg_pace_seconds_per_km int,
  avg_heart_rate int,
  max_heart_rate int,
  total_calories int,
  avg_cadence int,
  total_elevation_gain_m decimal(6,1),
  splits jsonb,
  heart_rate_data jsonb,
  route_polyline text,
  weather_temp_c decimal(4,1),
  weather_humidity int,
  weather_condition varchar(50),
  memo text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE TRIGGER set_updated_at_workout_logs
  BEFORE UPDATE ON workout_logs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 8. coaching_messages (1:N)
-- ============================================
CREATE TABLE coaching_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  plan_id uuid REFERENCES training_plans(id) ON DELETE SET NULL,
  week_id uuid REFERENCES training_weeks(id) ON DELETE SET NULL,
  session_id uuid REFERENCES training_sessions(id) ON DELETE SET NULL,
  message_type varchar(30) NOT NULL
    CHECK (message_type IN (
      'plan_overview', 'weekly_review', 'session_feedback',
      'pace_adjustment', 'encouragement', 'plan_adjustment'
    )),
  title varchar(200),
  content text NOT NULL,
  llm_model varchar(50),
  llm_prompt_snapshot jsonb,
  token_usage jsonb,
  is_read boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- ============================================
-- INDEXES
-- ============================================

-- 활성 플랜: 사용자당 최대 1개
CREATE UNIQUE INDEX idx_one_active_plan_per_user
  ON training_plans (user_id) WHERE status = 'active';

-- 운동 기록 소스별 중복 방지
CREATE UNIQUE INDEX idx_unique_workout_source
  ON workout_logs (user_id, source, external_id) WHERE external_id IS NOT NULL;

-- 조회 성능 인덱스
CREATE INDEX idx_workout_logs_user_date
  ON workout_logs (user_id, workout_date DESC);
CREATE INDEX idx_training_sessions_plan_date
  ON training_sessions (plan_id, session_date);
CREATE INDEX idx_training_plans_user_status
  ON training_plans (user_id, status);
CREATE INDEX idx_race_records_user_date
  ON race_records (user_id, race_date DESC);
CREATE INDEX idx_coaching_messages_user_unread
  ON coaching_messages (user_id, is_read) WHERE is_read = false;

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE strava_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE race_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_weeks ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE coaching_messages ENABLE ROW LEVEL SECURITY;

-- user_profiles: PK = auth.uid()
CREATE POLICY "user_profiles_all" ON user_profiles
  FOR ALL USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- strava_connections
CREATE POLICY "strava_connections_all" ON strava_connections
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- race_records
CREATE POLICY "race_records_all" ON race_records
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- training_plans
CREATE POLICY "training_plans_all" ON training_plans
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- training_weeks: plan_id를 통해 소유권 확인
CREATE POLICY "training_weeks_all" ON training_weeks
  FOR ALL USING (
    plan_id IN (SELECT id FROM training_plans WHERE user_id = auth.uid())
  )
  WITH CHECK (
    plan_id IN (SELECT id FROM training_plans WHERE user_id = auth.uid())
  );

-- training_sessions: plan_id를 통해 소유권 확인
CREATE POLICY "training_sessions_all" ON training_sessions
  FOR ALL USING (
    plan_id IN (SELECT id FROM training_plans WHERE user_id = auth.uid())
  )
  WITH CHECK (
    plan_id IN (SELECT id FROM training_plans WHERE user_id = auth.uid())
  );

-- workout_logs
CREATE POLICY "workout_logs_all" ON workout_logs
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- coaching_messages
CREATE POLICY "coaching_messages_all" ON coaching_messages
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
