# Phase별 연동 가이드

> 각 Phase에서 필요한 MCP, 외부 서비스, 키 발급 정리

---

## 전체 요약

| Phase | 주요 작업 | 필요한 MCP | 필요한 키/서비스 |
|-------|----------|-----------|----------------|
| 1 | 프로젝트 초기화 + 테마 | 없음 | 없음 |
| 2 | DB + 온보딩 화면 | ✅ Supabase MCP | Supabase URL + anon key |
| 3 | 메인 탭 + 훈련표 생성 | Supabase MCP | OpenAI API Key |
| 4 | HealthKit/Strava 연동 | Supabase MCP | Strava Client ID/Secret |
| 5 | AI 코칭 + 날씨 | Supabase MCP | OpenWeatherMap API Key |
| 6 | 소셜 로그인 + 폴리싱 | Supabase MCP | Apple/Google/Kakao 키 |

| MCP | 연동 시점 | 비고 |
|-----|----------|------|
| **Supabase MCP** | ✅ Phase 2 전 (완료) | DB 조작, 마이그레이션 |
| **Figma MCP** | 선택적, Phase 1~3 | 레이아웃 참고용 (필수 아님) |

---

## Phase 1: 프로젝트 초기화 + 테마 ✅ 완료

```
필요한 MCP: 없음
필요한 키: 없음
```

---

## Phase 2: DB + 온보딩 화면 ← 현재 단계

```
필요한 MCP:
  ✅ Supabase MCP (완료)

필요한 키:
  ✅ Supabase URL + anon key (완료)

선택적:
  - Figma MCP: 온보딩 화면 레이아웃 참고할 때 유용
    하지만 SCREEN_DESIGN.md로 충분하므로 없어도 됨

소셜 로그인은 Phase 6으로 미룸 (임시 우회 처리)
```

### Figma MCP 연동 방법 (필요 시)
```bash
# Claude Code 종료 후
/exit

# Figma MCP 추가 (Personal Access Token 필요)
# Figma → Settings → Personal Access Tokens에서 발급
claude mcp add figma -- npx -y figma-developer-mcp --figma-api-key YOUR_FIGMA_TOKEN

# Claude Code 다시 실행
claude
```

Figma MCP는 Claude Code가 Figma 파일을 읽어서 레이아웃, 컬러, 간격 등을 확인할 수 있게 해줌.
단, 우리는 DESIGN_SYSTEM.md를 스타일 기준으로 쓰기로 했으므로 **필수는 아님.**
Figma 디자인과 코드의 레이아웃을 맞추고 싶을 때 활용하면 좋음.

---

## Phase 3: 메인 탭 + 훈련표 생성

```
필요한 MCP:
  ✅ Supabase MCP (이미 연동됨)

필요한 키:
  🔑 OpenAI API Key (새로 발급 필요)

준비할 것:
  1. OpenAI API Key 발급
     → platform.openai.com → API Keys → Create new secret key
  2. .env 파일에 추가
     OPENAI_API_KEY=sk-...
     OPENAI_MODEL=gpt-4o

선택적:
  - Figma MCP: 메인 탭 화면 레이아웃 참고
```

---

## Phase 4: HealthKit/Strava 연동

```
필요한 MCP:
  ✅ Supabase MCP (이미 연동됨)

필요한 키:
  🔑 Strava API Client ID + Client Secret (새로 발급 필요)

준비할 것:
  1. Strava API 앱 생성
     → strava.com/settings/api → My API Application
     → Application Name, Website, Callback Domain 입력
     → Client ID + Client Secret 메모
  2. .env 파일에 추가
     STRAVA_CLIENT_ID=...
     STRAVA_CLIENT_SECRET=...

참고:
  - HealthKit은 별도 키 없음 (iOS 네이티브, Info.plist 권한 설정만 필요)
  - Strava API는 무료 (rate limit: 15분당 200, 일 2,000)
```

---

## Phase 5: AI 코칭 + 날씨

```
필요한 MCP:
  ✅ Supabase MCP (이미 연동됨)

필요한 키:
  ✅ OpenAI API Key (Phase 3에서 이미 발급)
  🔑 OpenWeatherMap API Key (새로 발급 필요)

준비할 것:
  1. OpenWeatherMap 가입 + API Key 발급
     → openweathermap.org → Sign Up → API Keys
     → 무료 플랜으로 충분 (분당 60회)
  2. .env 파일에 추가
     OPENWEATHERMAP_API_KEY=...
```

---

## Phase 6: 소셜 로그인 + 폴리싱

```
필요한 MCP:
  ✅ Supabase MCP (이미 연동됨)

필요한 키:
  🔑 Apple Sign-in (Apple Developer 계정 필요)
  🔑 Google Sign-in (Google Cloud Console)
  🔑 Kakao 로그인 (Kakao Developers)

준비할 것:

1. Apple Sign-in
   → Apple Developer 계정 필요 ($99/년)
   → Certificates, Identifiers & Profiles → App ID에 Sign in with Apple 활성화
   → Supabase Auth → Apple 프로바이더 설정

2. Google Sign-in
   → Google Cloud Console → OAuth 2.0 Client ID 생성
   → Supabase Auth → Google 프로바이더 설정
   → Client ID + Client Secret

3. Kakao 로그인
   → Kakao Developers → 앱 생성
   → REST API Key 발급
   → Supabase Auth에 Custom OAuth Provider로 연동 (추가 작업 필요)
   → KAKAO_APP_KEY=...

4. .env 파일에 추가
   KAKAO_APP_KEY=...
   (Apple, Google은 Supabase 대시보드에서 설정)
```

---

## .env 파일 최종 형태

```bash
# === Phase 2에서 추가 ===
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# === Phase 3에서 추가 ===
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o

# === Phase 4에서 추가 ===
STRAVA_CLIENT_ID=...
STRAVA_CLIENT_SECRET=...

# === Phase 5에서 추가 ===
OPENWEATHERMAP_API_KEY=...

# === Phase 6에서 추가 ===
KAKAO_APP_KEY=...
```

---

## MCP 연동 명령어 모음

```bash
# Supabase MCP (Phase 2 전) ✅ 완료
claude mcp add supabase -- npx -y @supabase/mcp-server-supabase@latest \
  --supabase-access-token YOUR_TOKEN

# Figma MCP (선택적, 필요 시)
claude mcp add figma -- npx -y figma-developer-mcp \
  --figma-api-key YOUR_FIGMA_TOKEN

# 연동된 MCP 확인
claude mcp list
```

---

*각 Phase 시작 전에 이 문서를 확인하고 필요한 키를 미리 준비하세요.*
