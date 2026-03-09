# Claude Code 개발 셋업 가이드

> 런닝 훈련 코치 앱 — Claude Code 멀티에이전트 작업 가이드
> 이 문서를 Claude Code에 전달하여 개발을 시작합니다.

---

## 1. 프로젝트 개요

### 1.1 앱 소개
- **앱 이름**: (미정)
- **플랫폼**: iOS (Flutter)
- **백엔드**: Supabase (PostgreSQL + Auth + Storage)
- **AI**: OpenAI API (LLM 프로바이더 추상화, 교체 가능)
- **핵심 기능**: HealthKit/Strava 데이터 기반 개인화 러닝 훈련표 생성 + AI 코칭

### 1.2 참고 문서 (필수 읽기)
| 문서 | 내용 | 우선순위 |
|------|------|----------|
| PROJECT_PLAN.md | 전체 기획서 (기능 명세, MVP 스코프) | ⭐⭐⭐ |
| DATA_MODEL.md | DB 테이블 설계, 인덱스, RLS 정책 | ⭐⭐⭐ |
| DESIGN_SYSTEM.md | 컬러, 타이포, 컴포넌트, 스페이싱 | ⭐⭐⭐ |
| SCREEN_DESIGN.md | 화면 목록, 구성요소, 네비게이션 | ⭐⭐ |
| Figma 디자인 | 레이아웃/구조 참고용 (스타일은 DESIGN_SYSTEM 우선) | ⭐ |

### 1.3 핵심 원칙
1. **DESIGN_SYSTEM.md가 스타일의 단일 진실 소스 (Single Source of Truth)** — Figma와 코드의 스타일이 다르면 DESIGN_SYSTEM.md를 따른다
2. **MVP 스코프에 집중** — PROJECT_PLAN.md의 Must Have만 먼저 구현
3. **LLM 프로바이더 추상화** — OpenAI에 직접 의존하지 않고 인터페이스를 통해 접근
4. **한국어 UI** — 라벨, 메시지는 한국어. 데이터 값(페이스, 거리)은 영문/숫자

---

## 2. 기술 스택 상세

### 2.1 프론트엔드 (Flutter)
```yaml
Flutter: 최신 stable
Dart: 최신 stable
상태관리: Riverpod 2.x
라우팅: go_router
HTTP: dio
로컬 저장소: shared_preferences
```

### 2.2 네이티브 연동
```yaml
HealthKit: health 패키지 (iOS)
Strava: OAuth2 + REST API (dio)
```

### 2.3 백엔드 (Supabase)
```yaml
Supabase: supabase_flutter 패키지
인증: Supabase Auth (Apple, Google, Kakao)
DB: PostgreSQL (Supabase 호스팅)
RLS: Row Level Security 활성화
```

### 2.4 AI
```yaml
OpenAI API: dart_openai 또는 HTTP 직접 호출
모델: gpt-4o (기본)
추상화: LLM Provider 인터페이스 → OpenAI 구현체
```

### 2.5 기타
```yaml
날씨: OpenWeatherMap API (무료 티어)
환경변수: flutter_dotenv
```

---

## 3. 프로젝트 구조

```
running_coach_app/
├── lib/
│   ├── main.dart
│   ├── app.dart                          # MaterialApp, 라우팅, 테마
│   │
│   ├── core/                             # 공통 인프라
│   │   ├── theme/
│   │   │   ├── app_theme.dart            # ThemeData (라이트/다크)
│   │   │   ├── app_colors.dart           # DESIGN_SYSTEM.md 컬러 정의
│   │   │   ├── app_typography.dart       # 타이포그래피 스케일
│   │   │   └── app_spacing.dart          # 스페이싱 토큰
│   │   ├── constants/
│   │   │   ├── training_zones.dart       # 훈련 존 컬러, 라벨 정의
│   │   │   └── app_constants.dart        # 앱 전역 상수
│   │   ├── utils/
│   │   │   ├── vdot_calculator.dart      # VDOT 계산 로직
│   │   │   ├── pace_formatter.dart       # 페이스 변환 (초 ↔ MM:SS)
│   │   │   ├── time_formatter.dart       # 시간 변환 (초 ↔ HH:MM:SS)
│   │   │   └── date_formatter.dart       # 날짜 포맷
│   │   ├── network/
│   │   │   ├── api_client.dart           # Dio 설정
│   │   │   └── api_exception.dart        # 에러 핸들링
│   │   └── extensions/                   # Dart 확장 함수
│   │
│   ├── data/                             # 데이터 레이어
│   │   ├── models/                       # 데이터 모델 (DB 매핑)
│   │   │   ├── user_profile.dart
│   │   │   ├── strava_connection.dart
│   │   │   ├── race_record.dart
│   │   │   ├── training_plan.dart
│   │   │   ├── training_week.dart
│   │   │   ├── training_session.dart
│   │   │   ├── workout_log.dart
│   │   │   └── coaching_message.dart
│   │   ├── repositories/                 # 데이터 접근 (Supabase 쿼리)
│   │   │   ├── auth_repository.dart
│   │   │   ├── user_repository.dart
│   │   │   ├── plan_repository.dart
│   │   │   ├── workout_repository.dart
│   │   │   ├── race_record_repository.dart
│   │   │   └── coaching_repository.dart
│   │   └── services/                     # 외부 서비스 연동
│   │       ├── supabase_service.dart     # Supabase 초기화
│   │       ├── healthkit_service.dart    # HealthKit 연동
│   │       ├── strava_service.dart       # Strava API 연동
│   │       ├── weather_service.dart      # 날씨 API
│   │       └── llm/                      # LLM 프로바이더 추상화
│   │           ├── llm_provider.dart     # 인터페이스 (abstract class)
│   │           ├── openai_provider.dart  # OpenAI 구현체
│   │           └── llm_prompts.dart      # 프롬프트 템플릿
│   │
│   ├── domain/                           # 비즈니스 로직
│   │   ├── usecases/
│   │   │   ├── generate_training_plan.dart   # 훈련표 생성
│   │   │   ├── match_workout_to_session.dart # 운동 기록 ↔ 세션 매칭
│   │   │   ├── calculate_weekly_stats.dart   # 주간 통계 계산
│   │   │   └── generate_coaching_message.dart # 코칭 메시지 생성
│   │   └── entities/                     # 도메인 엔티티 (UI용 변환 모델)
│   │
│   └── presentation/                     # UI 레이어
│       ├── common/                       # 공통 위젯
│       │   ├── widgets/
│       │   │   ├── training_session_card.dart
│       │   │   ├── stat_card.dart
│       │   │   ├── weather_card.dart
│       │   │   ├── coaching_message_card.dart
│       │   │   ├── progress_bar.dart
│       │   │   ├── training_type_badge.dart
│       │   │   ├── km_split_bar.dart
│       │   │   └── social_login_button.dart
│       │   └── layouts/
│       │       └── main_tab_layout.dart  # 하단 탭 네비게이션
│       │
│       ├── auth/                         # A-1, A-2
│       │   ├── splash_screen.dart
│       │   └── login_screen.dart
│       │
│       ├── onboarding/                   # B-1 ~ B-5
│       │   ├── profile_setup_screen.dart
│       │   ├── running_experience_screen.dart
│       │   ├── data_connection_screen.dart
│       │   ├── race_record_input_screen.dart
│       │   └── goal_setting_screen.dart
│       │
│       ├── home/                         # C-1
│       │   ├── home_screen.dart
│       │   └── providers/
│       │       └── home_provider.dart
│       │
│       ├── plan/                         # C-2, D-1, D-5, D-6
│       │   ├── plan_screen.dart
│       │   ├── session_detail_screen.dart
│       │   ├── plan_create_screen.dart
│       │   ├── plan_detail_screen.dart
│       │   └── providers/
│       │       └── plan_provider.dart
│       │
│       ├── records/                      # C-3, D-2
│       │   ├── records_screen.dart
│       │   ├── workout_detail_screen.dart
│       │   └── providers/
│       │       └── records_provider.dart
│       │
│       ├── my/                           # C-4, D-3, D-7, D-8
│       │   ├── my_page_screen.dart
│       │   ├── weekly_review_screen.dart
│       │   ├── race_records_screen.dart
│       │   ├── settings_screen.dart
│       │   └── providers/
│       │       └── my_provider.dart
│       │
│       └── router.dart                   # go_router 라우팅 설정
│
├── ios/                                  # iOS 네이티브 설정
│   └── Runner/
│       └── Info.plist                    # HealthKit, 소셜 로그인 설정
│
├── assets/                               # 에셋
│   ├── images/
│   └── fonts/
│
├── .env                                  # 환경변수 (gitignore)
├── .env.example                          # 환경변수 예시
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

## 4. 개발 페이즈 (단계별 구현 순서)

### Phase 1: 프로젝트 초기화 + 테마
> **목표**: 앱이 실행되고, 디자인 시스템이 코드로 구현됨

```
작업 목록:
1. Flutter 프로젝트 생성 (iOS만)
2. pubspec.yaml 패키지 추가
3. DESIGN_SYSTEM.md 기반 테마 구현
   - app_colors.dart (라이트/다크 모드 컬러)
   - app_typography.dart (폰트 스케일)
   - app_spacing.dart (스페이싱 토큰)
   - app_theme.dart (ThemeData 조합)
   - training_zones.dart (훈련 존 컬러/라벨)
4. 공통 위젯 구현 (DESIGN_SYSTEM.md의 컴포넌트)
   - TrainingSessionCard
   - StatCard
   - WeatherCard
   - CoachingMessageCard
   - ProgressBar
   - TrainingTypeBadge
   - SocialLoginButton
5. go_router 기본 라우팅 설정
6. 하단 탭 네비게이션 (MainTabLayout)

완료 조건: 
- 앱 실행 시 빈 탭 네비게이션 표시
- 라이트/다크 모드 전환 동작
- 공통 위젯 스토리보드 화면에서 확인 가능
```

### Phase 2: 인증 + 온보딩
> **목표**: 소셜 로그인 후 온보딩 플로우 완료까지

```
작업 목록:
1. Supabase 프로젝트 생성 + 설정
2. DB 테이블 생성 (DATA_MODEL.md의 SQL)
   - user_profiles
   - strava_connections
   - race_records
   - training_plans, training_weeks, training_sessions
   - workout_logs
   - coaching_messages
   - 인덱스 + RLS 정책
3. Supabase Auth 설정
   - Apple Sign-in
   - Google Sign-in
   - Kakao (Custom OAuth Provider)
4. 인증 화면 구현
   - A-1 스플래시 (자동 로그인 체크)
   - A-2 로그인 (소셜 로그인 3종)
5. 온보딩 플로우 구현
   - B-1 프로필 입력
   - B-2 러닝 경험 선택
   - B-3 데이터 연동 (HealthKit 권한 + Strava OAuth)
   - B-4 대회 기록 입력 (VDOT 자동 계산)
   - B-5 첫 목표 설정

완료 조건:
- Apple/Google/Kakao 로그인 동작
- 온보딩 5단계 완료 후 메인 화면 진입
- user_profiles, race_records 데이터 저장 확인
```

### Phase 3: 메인 탭 + 훈련표
> **목표**: 핵심 기능 — 훈련표 생성 및 표시

```
작업 목록:
1. LLM 프로바이더 추상화 구현
   - LLMProvider 인터페이스
   - OpenAIProvider 구현체
   - 프롬프트 템플릿 (훈련표 생성용)
2. VDOT 계산 로직 구현
   - 대회 기록 → VDOT 점수 계산 (프로필 표시용)
   - VDOT → 페이스 존 (E/M/T/I/R) 계산
3. 훈련표 생성 유스케이스
   - 목표 기록 있음: 목표 기록 기반 페이스 존 계산 → 훈련표 생성
   - 완주 목표 (기록 없음): VDOT 점수 기반 페이스 존 계산 → 훈련표 생성
   - LLM으로 주기화 훈련표 구성
   - training_plans + training_weeks + training_sessions 저장
4. 메인 탭 화면 구현
   - C-1 홈 (오늘의 훈련, 주간 진행률, 코칭 메시지)
   - C-2 플랜 (주차별 훈련표, 일별 세션 목록)
   - C-3 기록 (빈 상태 — Phase 4에서 데이터 연동)
   - C-4 마이페이지 (프로필, 메뉴)
5. 상세 화면
   - D-1 훈련 세션 상세
   - D-5 플랜 생성 (온보딩 이후 추가 플랜)
   - D-6 플랜 상세/관리

완료 조건:
- 목표 설정 후 LLM이 훈련표 생성
- 주차별/일별 훈련 세션 표시
- 세션 상세에서 목표 페이스, 코치 설명 확인
```

### Phase 4: HealthKit/Strava 연동 + 운동 기록
> **목표**: 실제 운동 데이터 수집 및 표시

```
작업 목록:
1. HealthKit 서비스 구현
   - 워크아웃 데이터 읽기 (거리, 시간, 심박수, 속도)
   - 백그라운드 동기화
2. Strava API 서비스 구현
   - OAuth2 토큰 관리 (자동 갱신)
   - Activity 데이터 가져오기 (splits, 고도, 케이던스)
3. 운동 기록 매칭 로직
   - workout_log 저장
   - 활성 플랜 세션에 자동 매칭 (날짜 + 거리 기반)
   - training_session 상태 업데이트
4. 운동 기록 화면 구현
   - C-3 기록 (월간 요약 + 기록 리스트)
   - D-2 운동 기록 상세 (구간 페이스, 심박수 그래프)
5. 홈 화면 업데이트
   - 오늘의 훈련 완료 시 실제 기록 표시
   - 주간 진행률 실데이터 반영

완료 조건:
- HealthKit에서 운동 데이터 자동 수집
- 활성 플랜 세션에 자동 매칭
- 운동 기록 상세에서 구간 페이스, 심박수 확인
```

### Phase 5: AI 코칭 + 날씨
> **목표**: LLM 코칭 메시지 + 날씨 기반 페이스 보정

```
작업 목록:
1. 날씨 서비스 구현
   - OpenWeatherMap API 연동
   - 당일 기온/습도/상태 가져오기
2. 코칭 메시지 생성
   - 주간 리뷰 (달성도 분석 + 다음 주 조언)
   - 세션 피드백 (운동 완료 후)
   - 날씨 기반 페이스 보정 메시지
3. 코칭 UI 구현
   - C-1 홈 코칭 메시지 카드
   - D-1 세션 상세 날씨 보정 카드
   - D-3 주간 리뷰 화면

완료 조건:
- 홈 화면에 날씨 + 페이스 보정 메시지 표시
- 운동 완료 시 AI 피드백 생성
- 주간 리뷰 확인 가능
```

### Phase 6: 나머지 + 폴리싱
> **목표**: 나머지 화면 구현 + 약관 적용 + 전체 품질 향상

```
작업 목록:
1. 나머지 화면
   - D-7 대회 기록 관리
   - D-8 설정 (다크모드 전환, 알림, Strava 관리)
2. 약관 적용
   - 개인정보 처리방침 + 서비스 이용약관 웹 호스팅 (URL 확보)
   - 온보딩 회원가입 시 약관 동의 UI (체크박스)
   - D-8 설정 화면에서 약관 WebView 열기
3. 플랜 관리 기능 완성
   - D-6 플랜 삭제 (UI TODO 연결 — deletePlan Repository 이미 구현됨)
   - D-6 플랜 취소 (상태 변경)
   - D-6 플랜 완료 처리
4. 에러 핸들링 + 빈 상태 처리
5. 로딩 상태 (Skeleton UI)
6. 앱 아이콘 + 스플래시 이미지
7. 전체 UI 일관성 점검 (DESIGN_SYSTEM 기준)
8. 테스트

완료 조건:
- 전체 화면 동작
- 에러/빈 상태 처리 완료
- 라이트/다크 모드 모두 정상
- 약관 동의 플로우 동작
- 설정에서 약관 확인 가능
```

---

## 5. 멀티에이전트 작업 분배

### 에이전트 구성 (권장)

```
🤖 Agent A — 인프라/백엔드
  담당: Supabase 설정, DB 마이그레이션, Repository 구현, 서비스 레이어
  참고: DATA_MODEL.md

🤖 Agent B — UI/프론트엔드
  담당: 화면 구현, 위젯, 라우팅, 상태관리
  참고: SCREEN_DESIGN.md, DESIGN_SYSTEM.md, Figma

🤖 Agent C — 비즈니스 로직/AI
  담당: VDOT 계산, LLM 프로바이더, 훈련표 생성, 코칭 메시지
  참고: PROJECT_PLAN.md

🤖 Agent D — 리뷰어/통합
  담당: 에이전트 간 코드 정합성 검증, 디자인 시스템 준수 체크
  참고: 전체 문서
```

### Phase별 에이전트 활용

| Phase | Agent A (백엔드) | Agent B (UI) | Agent C (로직) | Agent D (리뷰) |
|-------|-----------------|-------------|---------------|---------------|
| 1 | - | 테마 + 공통 위젯 | - | 디자인 시스템 준수 체크 |
| 2 | Supabase + DB + Auth | 인증 + 온보딩 화면 | VDOT 계산 | 통합 테스트 |
| 3 | Repository 구현 | 메인 탭 + 상세 화면 | LLM + 훈련표 생성 | API ↔ UI 정합성 |
| 4 | HealthKit + Strava | 기록 화면 | 매칭 로직 | 데이터 흐름 검증 |
| 5 | 날씨 API | 코칭 UI | 코칭 메시지 생성 | 전체 흐름 테스트 |
| 6 | - | 나머지 화면 + 폴리싱 | - | 최종 검수 |

---

## 6. 환경 설정

### 6.1 환경변수 (.env)
```
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# OpenAI
OPENAI_API_KEY=your-openai-key
OPENAI_MODEL=gpt-4o

# Strava
STRAVA_CLIENT_ID=your-client-id
STRAVA_CLIENT_SECRET=your-client-secret

# Weather
OPENWEATHERMAP_API_KEY=your-api-key

# Kakao
KAKAO_APP_KEY=your-kakao-key
```

### 6.2 iOS 설정 (Info.plist)
```xml
<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>운동 데이터를 분석하여 맞춤 훈련표를 제공합니다</string>
<key>NSHealthUpdateUsageDescription</key>
<string>훈련 데이터를 Apple Health에 기록합니다</string>

<!-- Location (날씨용) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>현재 위치의 날씨를 확인하여 훈련 페이스를 보정합니다</string>
```

### 6.3 Supabase 초기 SQL
```sql
-- DATA_MODEL.md의 전체 테이블 생성 SQL을 여기에 실행
-- 순서: user_profiles → strava_connections → race_records 
--       → training_plans → training_weeks → training_sessions 
--       → workout_logs → coaching_messages
-- 이후: 인덱스 생성 → RLS 정책 적용
```

---

## 7. CLAUDE.md (Claude Code 프로젝트 루트에 배치)

아래 내용을 프로젝트 루트의 `CLAUDE.md`에 배치하면 Claude Code가 자동으로 참고합니다:

```markdown
# Running Coach App — Claude Code 가이드

## 프로젝트 정보
- Flutter iOS 앱 (런닝 훈련 코치)
- 상태관리: Riverpod, 라우팅: go_router
- 백엔드: Supabase (PostgreSQL)
- AI: OpenAI API (추상화된 LLM Provider)

## 필수 참고 문서
1. PROJECT_PLAN.md — 기능 명세, MVP 스코프
2. DATA_MODEL.md — DB 설계, 테이블 구조
3. DESIGN_SYSTEM.md — **스타일의 단일 진실 소스**
4. SCREEN_DESIGN.md — 화면 목록, 구성요소

## 핵심 규칙
- 스타일은 항상 DESIGN_SYSTEM.md를 따른다 (Figma보다 우선)
- 컬러는 app_colors.dart에 정의된 것만 사용
- 라이트/다크 모드 둘 다 지원
- Primary 컬러: Indigo Blue (#5856D6 light / #7B79FF dark)
- 훈련 존 컬러: training_zones.dart 참고
- 시간은 초 단위(int)로 저장, 표시 시 MM:SS 변환
- 한국어 라벨, 영문/숫자 데이터
- LLM은 반드시 LLMProvider 인터페이스를 통해 접근

## 코드 컨벤션
- 파일명: snake_case
- 클래스명: PascalCase
- Riverpod Provider 사용
- 모든 위젯은 const constructor 가능하면 사용
- 에러 핸들링: try-catch + 사용자 친화적 메시지
```

---

## 8. 시작하기

### Claude Code에서 첫 번째 명령

```
Phase 1을 시작합니다.

참고 문서:
- DESIGN_SYSTEM.md (컬러, 타이포, 컴포넌트 정의)
- SCREEN_DESIGN.md (화면 목록, 네비게이션)

작업:
1. Flutter 프로젝트 생성
2. pubspec.yaml에 필요 패키지 추가
3. DESIGN_SYSTEM.md를 코드로 변환:
   - lib/core/theme/app_colors.dart (라이트/다크 모드)
   - lib/core/theme/app_typography.dart
   - lib/core/theme/app_spacing.dart
   - lib/core/theme/app_theme.dart
   - lib/core/constants/training_zones.dart
4. DESIGN_SYSTEM.md의 컴포넌트를 Flutter 위젯으로 구현:
   - lib/presentation/common/widgets/ 아래에 각 위젯
5. 하단 탭 네비게이션 + go_router 기본 라우팅
6. 앱 실행 확인

디자인 시스템 준수가 최우선입니다. Figma보다 DESIGN_SYSTEM.md를 따르세요.
```

---

*이 문서는 개발 진행에 따라 업데이트됩니다.*
