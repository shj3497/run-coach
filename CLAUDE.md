# Running Coach App

## 프로젝트 정보
AI 기반 런닝 훈련 코치 모바일 앱. HealthKit/Strava 데이터와 VDOT 분석을 기반으로 개인화 훈련표를 생성하고, LLM 코칭을 제공합니다.

- **플랫폼**: Flutter (iOS 우선)
- **상태관리**: Riverpod 2.x
- **라우팅**: go_router
- **백엔드**: Supabase (PostgreSQL + Auth)
- **AI**: OpenAI API (LLMProvider 인터페이스로 추상화)
- **데이터 소스**: HealthKit (필수) + Strava API (선택)

## 필수 참고 문서 (docs/ 폴더)
작업 전 반드시 관련 문서를 읽어주세요:

| 문서 | 내용 | 언제 읽어야 하나 |
|------|------|-----------------|
| `docs/CLAUDE_CODE_SETUP.md` | **개발 가이드 전체** — 페이즈별 작업, 프로젝트 구조, 멀티에이전트 분배 | 최초 1회 필수 |
| `docs/PROJECT_PLAN.md` | 기획서 — 기능 명세, MVP 스코프, 기술 결정사항 | 기능 구현 시 |
| `docs/DATA_MODEL.md` | DB 설계 — 8개 테이블, 인덱스, RLS, 데이터 흐름 | DB/Repository 작업 시 |
| `docs/DESIGN_SYSTEM.md` | **스타일 단일 진실 소스** — 컬러, 타이포, 컴포넌트, 스페이싱 | UI 작업 시 항상 |
| `docs/SCREEN_DESIGN.md` | 화면 설계 — 17개 화면 목록, 구성요소, 네비게이션 | 화면 구현 시 |

## 핵심 규칙

### 스타일
- **DESIGN_SYSTEM.md가 스타일 최우선** (Figma 디자인보다 우선)
- Primary: Indigo Blue (#5856D6 light / #7B79FF dark)
- 라이트/다크 모드 둘 다 지원
- 컬러는 `app_colors.dart`에 정의된 것만 사용
- 훈련 존 컬러: `training_zones.dart` 참고
- Apple 스타일 미니멀 디자인

### 데이터
- 시간 저장: 초 단위 (int), 표시 시 MM:SS 또는 HH:MM:SS 변환
- 페이스 저장: 초/km (int), 표시 시 M:SS/km 변환
- 가변 데이터(splits, 심박수 시계열): jsonb
- 활성 플랜은 사용자당 최대 1개 (DB partial unique index)

### 훈련 존 용어 (UI 표시 규칙)
- **약어 사용 금지**: E런, T런, M페이스 ❌
- **한글 풀네임 사용**: 이지런, 템포런, 마라톤페이스 ✅
- 이지런 (Easy Run) → 초록
- 마라톤페이스 (Marathon Pace) → 파랑
- 템포런 (Threshold Run) → 노랑
- 인터벌 (Interval) → 주황
- 반복달리기 (Repetition) → 빨강
- 장거리런 (Long Run) → 보라
- 휴식 (Rest) → 회색

### VDOT 및 플랜 생성 로직
- **VDOT 점수**: 기록증(대회 기록) 기반으로 계산, 프로필에 표시용
- **플랜 생성 (목표 기록 있음)**: 사용자가 입력한 목표 기록 기반으로 페이스 존 계산 → 훈련표 생성
- **플랜 생성 (완주 목표, 기록 없음)**: VDOT 점수 기반으로 페이스 존 계산 → 훈련표 생성
- ⚠️ 플랜 페이스 존은 기록증 VDOT이 아닌 **목표 기록 기준**이 기본값

### AI/LLM
- LLM은 반드시 `LLMProvider` 인터페이스를 통해 접근
- OpenAI에 직접 의존하지 않음
- 프롬프트 템플릿은 `llm_prompts.dart`에서 관리

### 코드 컨벤션
- 파일명: snake_case
- 클래스명: PascalCase
- Riverpod Provider 패턴 사용
- const constructor 가능하면 항상 사용
- 한국어 라벨, 영문/숫자 데이터 값

## 개발 페이즈 요약
1. **프로젝트 초기화 + 테마** — 디자인 시스템 코드 변환, 공통 위젯
2. **인증 + 온보딩** — Supabase DB, 소셜 로그인 (Apple/Google/Kakao), 온보딩
3. **메인 탭 + 훈련표** — LLM 훈련표 생성, 핵심 4개 탭 화면
4. **HealthKit/Strava 연동** — 운동 데이터 수집, 세션 매칭
5. **AI 코칭 + 날씨** — 코칭 메시지, 페이스 보정
6. **나머지 + 폴리싱** — 설정, 에러 처리, UI 점검

상세 내용은 `docs/CLAUDE_CODE_SETUP.md` 참고.
