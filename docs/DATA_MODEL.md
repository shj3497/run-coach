# 데이터 모델 설계

> 런닝 훈련 코치 앱 — Supabase (PostgreSQL) 기반

---

## 1. 엔티티 관계도 (ERD 개요)

```
users (Supabase Auth)
  ├→ user_profiles (1:1)
  ├→ strava_connections (1:1)
  ├→ race_records (1:N) — 대회 기록
  ├→ training_plans (1:N) — 훈련 플랜 (활성은 최대 1개)
  │     ├→ training_weeks (1:N) — 주차
  │     │     └→ training_sessions (1:N) — 일별 훈련
  │     └→ coaching_messages (1:N) — LLM 코칭 메시지
  └→ workout_logs (1:N) — 실제 운동 기록 (플랜과 독립)
        └→ training_sessions (N:1, nullable) — 활성 플랜 세션에 연결 가능
```

---

## 2. 테이블 상세

### 2.1 user_profiles

사용자 프로필. Supabase Auth의 `auth.users`와 1:1 관계.

| 컬럼 | 타입 | 제약조건 | 설명 |
|------|------|----------|------|
| id | uuid | PK, FK → auth.users.id | Supabase Auth 사용자 ID |
| nickname | varchar(50) | NOT NULL | 닉네임 |
| birth_year | int | nullable | 출생 연도 (나이대 기반 분석용) |
| gender | varchar(10) | nullable | 성별 (훈련 강도 참고) |
| height_cm | decimal(5,1) | nullable | 키 (cm) |
| weight_kg | decimal(5,1) | nullable | 체중 (kg) |
| running_experience | varchar(20) | nullable | 러닝 경험 수준: beginner / intermediate / advanced |
| preferred_distance | varchar(20) | nullable | 선호 종목: 5k / 10k / half / full |
| weekly_available_days | int | nullable | 주간 가용 훈련일수 (1~7) |
| timezone | varchar(50) | DEFAULT 'Asia/Seoul' | 사용자 타임존 |
| created_at | timestamptz | DEFAULT now() | 생성일 |
| updated_at | timestamptz | DEFAULT now() | 수정일 |

**설계 의도:**
- `auth.users`에는 이메일, 소셜 로그인 정보 등 인증 관련만 저장 (Supabase Auth가 관리)
- 앱에서 필요한 추가 프로필 정보는 이 테이블에 저장
- `running_experience`는 초기 온보딩 시 입력받거나, HealthKit/Strava 데이터 분석 후 자동 분류

---

### 2.2 strava_connections

Strava OAuth 연동 정보. 사용자당 최대 1개.

| 컬럼 | 타입 | 제약조건 | 설명 |
|------|------|----------|------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| user_id | uuid | FK → user_profiles.id, UNIQUE | 사용자 ID |
| strava_athlete_id | bigint | NOT NULL | Strava 선수 ID |
| access_token | text | NOT NULL | Strava 액세스 토큰 (암호화 저장) |
| refresh_token | text | NOT NULL | Strava 리프레시 토큰 (암호화 저장) |
| token_expires_at | timestamptz | NOT NULL | 토큰 만료 시간 |
| scope | text | NOT NULL | 부여된 권한 범위 |
| is_active | boolean | DEFAULT true | 연동 활성화 여부 |
| last_sync_at | timestamptz | nullable | 마지막 동기화 시간 |
| created_at | timestamptz | DEFAULT now() | 연동 생성일 |
| updated_at | timestamptz | DEFAULT now() | 수정일 |

**설계 의도:**
- Strava 토큰은 6시간마다 만료 → `refresh_token`으로 자동 갱신
- `access_token`, `refresh_token`은 암호화하여 저장 (Supabase Vault 또는 앱 레벨 암호화)
- `is_active`로 사용자가 연동을 일시 해제할 수 있음

---

### 2.3 race_records

사용자가 수동 입력하는 대회 기록. VDOT 점수 산출의 기반 데이터.

| 컬럼 | 타입 | 제약조건 | 설명 |
|------|------|----------|------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| user_id | uuid | FK → user_profiles.id | 사용자 ID |
| race_name | varchar(100) | NOT NULL | 대회 이름 (예: "2025 JTBC 마라톤") |
| race_date | date | NOT NULL | 대회 날짜 |
| distance_km | decimal(6,2) | NOT NULL | 거리 (km) — 5, 10, 21.0975, 42.195 등 |
| finish_time_seconds | int | NOT NULL | 완주 시간 (초 단위 저장, 표시는 HH:MM:SS) |
| vdot_score | decimal(4,1) | nullable | 이 기록에서 산출된 VDOT 점수 (앱이 자동 계산) |
| memo | text | nullable | 메모 (컨디션, 날씨, 소감 등) |
| created_at | timestamptz | DEFAULT now() | 생성일 |
| updated_at | timestamptz | DEFAULT now() | 수정일 |

**설계 의도:**
- `finish_time_seconds`: 초 단위로 저장하면 계산이 편하고, 표시할 때만 HH:MM:SS로 변환
- `distance_km`: 정확한 거리 저장 (하프마라톤 = 21.0975km)
- `vdot_score`: 대회 기록 입력 시 앱이 룰 기반으로 자동 계산하여 저장
- 가장 최근 대회 기록의 VDOT을 훈련표 생성에 사용

---

### 2.4 training_plans

훈련 플랜. 사용자가 여러 개 생성 가능하나 **활성(active) 상태는 최대 1개.**

| 컬럼 | 타입 | 제약조건 | 설명 |
|------|------|----------|------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| user_id | uuid | FK → user_profiles.id | 사용자 ID |
| plan_name | varchar(100) | NOT NULL | 플랜 이름 (예: "2025 JTBC 하프 1:55 도전") |
| status | varchar(20) | NOT NULL, DEFAULT 'upcoming' | 상태: active / upcoming / completed / cancelled |
| goal_race_name | varchar(100) | nullable | 목표 대회 이름 |
| goal_race_date | date | nullable | 목표 대회 날짜 |
| goal_distance_km | decimal(6,2) | NOT NULL | 목표 거리 (km) |
| goal_time_seconds | int | nullable | 목표 완주 시간 (초). null이면 "완주" 목표 |
| vdot_score | decimal(4,1) | nullable | 플랜 생성 시 기준 VDOT 점수 |
| total_weeks | int | NOT NULL | 총 훈련 주수 |
| start_date | date | NOT NULL | 훈련 시작일 |
| end_date | date | NOT NULL | 훈련 종료일 (≈ 대회 날짜) |
| training_days_per_week | int | NOT NULL | 주간 훈련일수 |
| pace_zones | jsonb | nullable | VDOT 기반 페이스 존 (E/M/T/I/R 각 페이스) |
| llm_context_snapshot | jsonb | nullable | LLM에 전달된 context 스냅샷 (재생성 시 참고용) |
| created_at | timestamptz | DEFAULT now() | 생성일 |
| updated_at | timestamptz | DEFAULT now() | 수정일 |

**설계 의도:**
- `status` 제약: `active`인 플랜은 사용자당 최대 1개 (DB 레벨 또는 앱 레벨에서 강제)
- `pace_zones` (jsonb): `{"E": "6:00-6:30", "M": "5:15", "T": "4:55", "I": "4:32", "R": "4:17"}` 형태. VDOT에서 계산된 결과 저장
- `llm_context_snapshot`: 훈련표 생성 시 LLM에 전달한 전체 context를 스냅샷으로 보관. 나중에 "왜 이런 훈련표가 나왔지?" 추적 가능
- `goal_time_seconds`가 null이면 단순 완주 목표

**DB 레벨 제약 (partial unique index):**
```sql
CREATE UNIQUE INDEX idx_one_active_plan_per_user 
ON training_plans (user_id) 
WHERE status = 'active';
```

---

### 2.5 training_weeks

훈련 주차. 플랜의 하위 단위.

| 컬럼 | 타입 | 제약조건 | 설명 |
|------|------|----------|------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| plan_id | uuid | FK → training_plans.id | 소속 플랜 |
| week_number | int | NOT NULL | 주차 번호 (1, 2, 3, ...) |
| start_date | date | NOT NULL | 해당 주 시작일 (월요일) |
| end_date | date | NOT NULL | 해당 주 종료일 (일요일) |
| phase | varchar(20) | NOT NULL | 훈련 단계: base / build / peak / taper |
| target_distance_km | decimal(6,1) | nullable | 이번 주 목표 총 거리 |
| weekly_summary | text | nullable | LLM이 생성한 주간 요약/목표 설명 |
| created_at | timestamptz | DEFAULT now() | 생성일 |

**설계 의도:**
- `phase`: 주기화 훈련의 단계. 기초(base) → 강화(build) → 절정(peak) → 테이퍼(taper)
- `UNIQUE(plan_id, week_number)` 제약으로 중복 주차 방지

---

### 2.6 training_sessions

일별 훈련 세션. 훈련표의 최소 단위.

| 컬럼 | 타입 | 제약조건 | 설명 |
|------|------|----------|------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| week_id | uuid | FK → training_weeks.id | 소속 주차 |
| plan_id | uuid | FK → training_plans.id | 소속 플랜 (조회 편의) |
| session_date | date | NOT NULL | 훈련 예정일 |
| day_of_week | int | NOT NULL | 요일 (1=월 ~ 7=일) |
| session_type | varchar(30) | NOT NULL | 훈련 유형 |
| title | varchar(100) | NOT NULL | 훈련 제목 (예: "이지런 8km", "인터벌 6x800m") |
| description | text | nullable | LLM이 생성한 훈련 상세 설명 |
| target_distance_km | decimal(5,1) | nullable | 목표 거리 (km) |
| target_duration_minutes | int | nullable | 목표 시간 (분) |
| target_pace | varchar(20) | nullable | 목표 페이스 (예: "5:30-6:00/km") |
| workout_detail | jsonb | nullable | 세부 훈련 구성 |
| status | varchar(20) | DEFAULT 'pending' | 상태: pending / completed / skipped / partial |
| completed_at | timestamptz | nullable | 실제 완료 시간 |
| created_at | timestamptz | DEFAULT now() | 생성일 |
| updated_at | timestamptz | DEFAULT now() | 수정일 |

**session_type 값:**
- `easy` — 이지런 (쉬운 달리기)
- `marathon_pace` — 마라톤페이스 (마라톤 페이스)
- `threshold` — 템포런 (역치 달리기)
- `interval` — 인터벌
- `repetition` — 반복달리기
- `long_run` — 장거리런
- `recovery` — 회복 조깅
- `cross_training` — 크로스트레이닝
- `rest` — 휴식일

**workout_detail (jsonb) 예시:**
```json
// 인터벌 훈련
{
  "warmup": { "distance_km": 2, "pace": "6:00/km" },
  "intervals": [
    { "reps": 6, "distance_m": 800, "pace": "4:32/km", "rest_seconds": 120 }
  ],
  "cooldown": { "distance_km": 2, "pace": "6:00/km" }
}

// 이지런
{
  "type": "steady",
  "pace_range": { "min": "5:54/km", "max": "6:29/km" }
}
```

---

### 2.7 workout_logs

실제 운동 기록. HealthKit 또는 Strava에서 수집. **플랜과 독립적으로 저장.**

| 컬럼 | 타입 | 제약조건 | 설명 |
|------|------|----------|------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| user_id | uuid | FK → user_profiles.id | 사용자 ID |
| session_id | uuid | FK → training_sessions.id, nullable | 연결된 훈련 세션 (없으면 자유 훈련) |
| source | varchar(20) | NOT NULL | 데이터 소스: healthkit / strava |
| external_id | varchar(100) | nullable | 외부 시스템 ID (Strava activity ID 등) |
| workout_date | date | NOT NULL | 운동 날짜 |
| started_at | timestamptz | NOT NULL | 운동 시작 시간 |
| ended_at | timestamptz | NOT NULL | 운동 종료 시간 |
| distance_km | decimal(6,2) | NOT NULL | 총 거리 (km) |
| duration_seconds | int | NOT NULL | 총 운동 시간 (초) |
| avg_pace_seconds_per_km | int | nullable | 평균 페이스 (초/km) |
| avg_heart_rate | int | nullable | 평균 심박수 |
| max_heart_rate | int | nullable | 최대 심박수 |
| total_calories | int | nullable | 총 소모 칼로리 |
| avg_cadence | int | nullable | 평균 케이던스 (Strava) |
| total_elevation_gain_m | decimal(6,1) | nullable | 총 고도 상승 (m, Strava) |
| splits | jsonb | nullable | 구간별 페이스 (Strava splits 데이터) |
| heart_rate_data | jsonb | nullable | 심박수 시계열 (HealthKit) |
| route_polyline | text | nullable | GPS 루트 (Strava encoded polyline) |
| weather_temp_c | decimal(4,1) | nullable | 운동 시 기온 (날씨 API) |
| weather_humidity | int | nullable | 운동 시 습도 (%) |
| weather_condition | varchar(50) | nullable | 날씨 상태 (맑음, 흐림, 비 등) |
| memo | text | nullable | 사용자 메모 |
| created_at | timestamptz | DEFAULT now() | 생성일 |
| updated_at | timestamptz | DEFAULT now() | 수정일 |

**설계 의도:**
- `session_id` nullable: 플랜 없이 달린 기록도 저장. 활성 플랜이 있으면 해당 세션에 연결
- `source`: 동일 운동이 HealthKit과 Strava 양쪽에서 올 수 있으므로, `UNIQUE(user_id, source, external_id)`로 중복 방지
- `splits` (jsonb): `[{"km": 1, "pace_seconds": 330}, {"km": 2, "pace_seconds": 325}, ...]`
- `heart_rate_data` (jsonb): `[{"timestamp": "...", "bpm": 145}, ...]` (HealthKit 시계열)
- `weather_*`: 운동 시점의 날씨를 저장해두면 LLM이 페이스 보정 코칭 시 참고 가능
- `route_polyline`: Strava의 encoded polyline. 추후 대회 코스 고저도 분석에 활용 가능

**중복 방지:**
```sql
CREATE UNIQUE INDEX idx_unique_workout_source 
ON workout_logs (user_id, source, external_id) 
WHERE external_id IS NOT NULL;
```

---

### 2.8 coaching_messages

LLM이 생성한 코칭 메시지.

| 컬럼 | 타입 | 제약조건 | 설명 |
|------|------|----------|------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| user_id | uuid | FK → user_profiles.id | 사용자 ID |
| plan_id | uuid | FK → training_plans.id, nullable | 관련 플랜 (없으면 일반 코칭) |
| week_id | uuid | FK → training_weeks.id, nullable | 관련 주차 |
| session_id | uuid | FK → training_sessions.id, nullable | 관련 세션 |
| message_type | varchar(30) | NOT NULL | 메시지 유형 |
| title | varchar(200) | nullable | 메시지 제목 |
| content | text | NOT NULL | LLM이 생성한 코칭 내용 |
| llm_model | varchar(50) | nullable | 사용된 LLM 모델 (예: "gpt-4o") |
| llm_prompt_snapshot | jsonb | nullable | LLM에 전달된 프롬프트 스냅샷 |
| token_usage | jsonb | nullable | 토큰 사용량 (비용 추적) |
| is_read | boolean | DEFAULT false | 사용자가 읽었는지 여부 |
| created_at | timestamptz | DEFAULT now() | 생성일 |

**message_type 값:**
- `plan_overview` — 훈련표 생성 시 전체 설명
- `weekly_review` — 주간 리뷰 (달성도 분석 + 다음 주 조언)
- `session_feedback` — 개별 훈련 완료 후 피드백
- `pace_adjustment` — 날씨/컨디션 기반 페이스 보정 조언
- `encouragement` — 동기부여 메시지
- `plan_adjustment` — 훈련표 재조정 제안

**설계 의도:**
- `llm_prompt_snapshot`: 디버깅 및 프롬프트 개선용. "이 코칭 메시지가 왜 이렇게 나왔지?" 추적 가능
- `token_usage`: `{"prompt_tokens": 1200, "completion_tokens": 500, "total_tokens": 1700, "cost_usd": 0.0035}` — 비용 모니터링

---

## 3. 인덱스 전략

```sql
-- 사용자별 활성 플랜 고유 제약
CREATE UNIQUE INDEX idx_one_active_plan_per_user 
ON training_plans (user_id) WHERE status = 'active';

-- 운동 기록 중복 방지
CREATE UNIQUE INDEX idx_unique_workout_source 
ON workout_logs (user_id, source, external_id) WHERE external_id IS NOT NULL;

-- 자주 사용되는 조회 패턴
CREATE INDEX idx_workout_logs_user_date ON workout_logs (user_id, workout_date DESC);
CREATE INDEX idx_training_sessions_plan_date ON training_sessions (plan_id, session_date);
CREATE INDEX idx_training_plans_user_status ON training_plans (user_id, status);
CREATE INDEX idx_race_records_user_date ON race_records (user_id, race_date DESC);
CREATE INDEX idx_coaching_messages_user_unread ON coaching_messages (user_id, is_read) WHERE is_read = false;
```

---

## 4. 데이터 흐름 시나리오

### 4.1 신규 사용자 온보딩

```
1. 소셜 로그인 (Apple/Google/Kakao)
   → auth.users 생성 (Supabase Auth)
   
2. 프로필 입력
   → user_profiles 생성
   
3. [선택] Strava 연동
   → strava_connections 생성
   
4. 대회 기록 입력
   → race_records 생성
   → vdot_score 자동 계산
   
5. 훈련 플랜 생성
   → training_plans 생성 (status: 'active')
   → training_weeks 생성 (N주)
   → training_sessions 생성 (각 주의 훈련일)
   → coaching_messages 생성 (plan_overview)
```

### 4.2 일일 훈련 사이클

```
1. 오늘의 훈련 확인
   → training_sessions WHERE plan_id = (활성 플랜) AND session_date = today
   
2. 날씨 기반 페이스 보정 (선택)
   → 날씨 API 호출 → LLM에 context 전달
   → coaching_messages 생성 (pace_adjustment)
   
3. 운동 완료 후 데이터 수집
   → HealthKit/Strava에서 데이터 가져옴
   → workout_logs 생성 (session_id 연결)
   → training_sessions.status 업데이트 (completed/partial)
   
4. [선택] 세션 피드백
   → coaching_messages 생성 (session_feedback)
```

### 4.3 주간 리뷰

```
1. 주간 데이터 집계
   → 해당 주 training_sessions 달성률 계산
   → 해당 주 workout_logs 합산 (거리, 시간, 심박수 등)
   
2. LLM 주간 리뷰 생성
   → coaching_messages 생성 (weekly_review)
```

### 4.4 플랜 전환

```
1. 현재 활성 플랜 완료/취소
   → training_plans.status = 'completed' 또는 'cancelled'
   
2. 예정 플랜 활성화
   → training_plans.status = 'active'
   (DB 제약이 자동으로 사용자당 1개만 active 허용)
```

---

## 5. Supabase RLS (Row Level Security) 정책

```sql
-- 모든 테이블에 기본 RLS 활성화
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE strava_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE race_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_weeks ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE coaching_messages ENABLE ROW LEVEL SECURITY;

-- 예시: 사용자는 자기 데이터만 접근 가능
CREATE POLICY "Users can only access own data" ON user_profiles
  FOR ALL USING (id = auth.uid());

CREATE POLICY "Users can only access own plans" ON training_plans
  FOR ALL USING (user_id = auth.uid());

-- 나머지 테이블도 동일 패턴
```

---

## 6. 설계 결정 사항 요약

| 결정 | 선택 | 이유 |
|------|------|------|
| 시간 저장 형식 | 초 단위 (int) | 계산 편의, 표시 시에만 MM:SS 변환 |
| 페이스 저장 형식 | 초/km (int) | 계산 편의 |
| 세부 데이터 저장 | jsonb | splits, 심박수 시계열 등 유연한 구조 |
| 플랜 활성 제약 | partial unique index | DB 레벨에서 보장 |
| 운동 기록 독립 저장 | session_id nullable | 플랜 없이도 기록 가능, 추후 매칭 |
| 날씨 데이터 | workout_logs에 저장 | 운동 시점 날씨를 기록과 함께 보관 |
| LLM 추적 | 프롬프트/토큰 스냅샷 저장 | 디버깅, 비용 관리, 프롬프트 개선 |
| 암호화 | Strava 토큰 | 민감 데이터 보호 |

---

*이 문서는 프로젝트 진행에 따라 지속 업데이트됩니다.*
