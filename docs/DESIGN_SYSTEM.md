# Design System — 런닝 훈련 코치 앱

> Google Stitch의 Design System Set 기능에 입력할 내용
> 이 시스템을 먼저 설정한 후 화면 생성을 시작하세요

---

## 1. Colors

### 🌞 Light Mode / 🌙 Dark Mode 둘 다 지원

### Primary (Indigo Blue)
| 이름 | 용도 | Light Mode | Dark Mode |
|------|------|-----------|----------|
| Primary | CTA 버튼, 활성 탭, 강조 요소 | #5856D6 | #7B79FF |
| Primary Dark | 버튼 pressed 상태 | #4240A8 | #5856D6 |
| Primary Light | 배지, 하이라이트 배경 | rgba(88, 86, 214, 0.12) | rgba(123, 121, 255, 0.15) |

### Background
| 이름 | 용도 | Light Mode | Dark Mode |
|------|------|-----------|----------|
| Background | 앱 전체 배경 | #F2F2F7 | #000000 |
| Surface | 카드, 모달 배경 | #FFFFFF | #1C1C1E |
| Surface Elevated | 올려진 카드, 드롭다운 | #FFFFFF (shadow) | #2C2C2E |

### Text
| 이름 | 용도 | Light Mode | Dark Mode |
|------|------|-----------|----------|
| Text Primary | 제목, 주요 텍스트 | #000000 | #FFFFFF |
| Text Secondary | 부가 설명, 라벨 | #8E8E93 | #8E8E93 |
| Text Disabled | 비활성 텍스트 | #C7C7CC | #48484A |

### Training Zone Colors (페이스 존별 컬러, 라이트/다크 공통)
| 이름 | 훈련 유형 (UI 표시명) | HEX |
|------|---------------------|-----|
| Zone Easy | 이지런 (Easy Run) | #34C759 (Green) |
| Zone Marathon | 마라톤페이스 (Marathon Pace) | #007AFF (Blue) |
| Zone Threshold | 템포런 (Threshold Run) | #FF9F0A (Yellow) |
| Zone Interval | 인터벌 (Interval) | #FF6B35 (Orange) |
| Zone Repetition | 반복달리기 (Repetition) | #FF3B30 (Red) |
| Zone Long Run | 장거리런 (Long Run) | #AF52DE (Purple) |
| Zone Rest | 휴식 (Rest) | #8E8E93 (Gray) |

> **용어 규칙**: UI에서는 한글 표시명을 사용한다. 괄호 안 영문은 코드/변수명용.
> ❌ "E런", "T런", "M페이스" (약어 사용 금지)
> ✅ "이지런", "템포런", "마라톤페이스" (한글 풀네임 사용)

### Status Colors (라이트/다크 공통)
| 이름 | 용도 | HEX |
|------|------|-----|
| Success | 완료, 목표 달성 | #34C759 |
| Warning | 주의, 날씨 경고 | #FF9F0A |
| Error | 미완료, 오류 | #FF3B30 |
| Info | 정보, 코칭 메시지 | #5856D6 (Primary) |

### Social Login Colors
| 이름 | 용도 | HEX |
|------|------|-----|
| Apple | Apple Sign-in 버튼 | #000000 (light) / #FFFFFF (dark) |
| Google | Google Sign-in 버튼 | #FFFFFF (light) / #1C1C1E (dark) |
| Kakao | 카카오 로그인 버튼 | #FEE500 |

> **컬러 체계는 Apple Human Interface Guidelines (iOS 18)를 기반으로 설계.**
> 라이트/다크 모드 전환 시 Primary가 자동으로 밝기 보정됨.

---

## 2. Typography

| 이름 | 용도 | 크기 | 굵기 | 행간 |
|------|------|------|------|------|
| Display | 스플래시 앱 이름 | 32px | Bold | 1.2 |
| H1 | 화면 제목 | 24px | Bold | 1.3 |
| H2 | 섹션 제목 | 20px | SemiBold | 1.3 |
| H3 | 카드 제목 | 17px | SemiBold | 1.4 |
| Body Large | 코칭 메시지, 설명 | 16px | Regular | 1.5 |
| Body | 일반 텍스트 | 14px | Regular | 1.5 |
| Body Small | 부가 정보, 라벨 | 12px | Regular | 1.4 |
| Caption | 날짜, 메타 정보 | 11px | Regular | 1.3 |
| Stats Large | 거리, 페이스 큰 숫자 | 36px | Bold | 1.1 |
| Stats Medium | 통계 숫자 | 24px | SemiBold | 1.2 |

**폰트:** Pretendard (한국어) / SF Pro (iOS 시스템, 영문/숫자)

---

## 3. Components (재사용 컴포넌트)

### 3.1 Training Session Card
```
용도: 훈련 세션 표시 (홈, 플랜 화면)
구성:
  - 좌측: 훈련 유형 컬러 바 (세로, 4px, 존 컬러)
  - 훈련 유형 배지 (예: "이지런", 존 컬러 배경)
  - 제목 (예: "이지런 8km")
  - 목표 페이스 + 예상시간
  - 우측: 상태 아이콘 (✅ 완료 / 🔲 예정 / ⚠️ 미완료)
스타일: Surface 배경, 16px radius, 16px padding
```

### 3.2 Stat Card
```
용도: 통계 표시 (운동 요약, 월간 요약)
구성:
  - 라벨 (Body Small, Text Secondary)
  - 숫자 (Stats Medium 또는 Stats Large)
  - 단위 (Body Small, Text Secondary)
스타일: Surface 배경, 12px radius, 12px padding
```

### 3.3 Weather Card
```
용도: 날씨 정보 + 페이스 보정 메시지
구성:
  - 날씨 아이콘 + 기온
  - AI 한줄 메시지
스타일: Surface Elevated 배경, 16px radius, 약간 따뜻한 톤
```

### 3.4 Coaching Message Card
```
용도: LLM 코칭 메시지 표시
구성:
  - AI 아이콘 (작은 로봇 또는 코치 아이콘)
  - 메시지 내용 (Body Large)
  - 타임스탬프 (Caption)
스타일: Surface 배경, 좌측에 Primary 컬러 액센트 바, 16px radius
```

### 3.5 Progress Bar
```
용도: 주간 진행률, 거리 달성률
구성:
  - 라벨 (좌: "3/5 세션", 우: "60%")
  - 바 (배경: Surface Elevated, 채움: Primary Indigo Blue)
  - 높이: 8px, radius: 4px
```

### 3.6 Social Login Button
```
용도: 소셜 로그인 (Apple / Google / Kakao)
구성:
  - 서비스 아이콘 (좌측)
  - 텍스트: "OOO로 시작하기"
  - 전체 너비
스타일: 각 서비스별 브랜드 컬러 적용, 50px 높이, 12px radius
```

### 3.7 Bottom Tab Navigation
```
용도: 메인 네비게이션
탭:
  - 홈 (Home icon)
  - 플랜 (Calendar icon)
  - 활동 (Chart/Activity icon)
  - 프로필 (Person icon)
스타일: Background 색상, 활성 탭은 Primary 컬러 아이콘 + 라벨
```

### 3.8 Training Type Badge
```
용도: 훈련 유형 태그
구성: 텍스트 + 존 컬러 배경 (투명도 20%) + 존 컬러 텍스트
크기: Body Small, 6px vertical padding, 10px horizontal padding, 8px radius
예시:
  - "이지런" → 초록 배경, 초록 텍스트
  - "템포런" → 노랑 배경, 노랑 텍스트
  - "인터벌" → 주황 배경, 주황 텍스트
  - "장거리런" → 보라 배경, 보라 텍스트
  - "휴식" → 회색 배경, 회색 텍스트
```

### 3.9 Km Split Bar
```
용도: 구간별 페이스 바 차트 (운동 기록 상세)
구성:
  - 좌: km 번호 (Body Small)
  - 중: 수평 바 (길이 = 페이스 상대값, 색상 = 존 컬러)
  - 우: 페이스 텍스트 (Body Small)
스타일: 바 높이 24px, 4px radius, 바 사이 간격 4px
```

### 3.10 Skeleton Loading
```
용도: 콘텐츠 로딩 시 플레이스홀더 (CircularProgressIndicator 대신 사용)
구성:
  - SkeletonBox: 직사각형 플레이스홀더 (카드, 텍스트 라인 등)
  - SkeletonCircle: 원형 플레이스홀더 (아바타, 아이콘 등)
스타일:
  - Light: #E5E5EA → #F2F2F7 shimmer
  - Dark: #2C2C2E → #3A3A3C shimmer
  - 애니메이션: 1.5초 주기 좌→우 shimmer, easeInOut
  - radius: 부모 컴포넌트와 동일 (카드=16px, 배지=8px 등)
적용 기준:
  - 콘텐츠 로딩 (화면, 카드, 리스트) → 스켈레톤 사용
  - 액션 로딩 (버튼 클릭, 폼 제출) → CircularProgressIndicator 유지
  - 장시간 작업 (AI 훈련표 생성) → 오버레이 + 상태 메시지 유지
```

---

## 4. Spacing & Layout

| 토큰 | 값 | 용도 |
|------|-----|------|
| xs | 4px | 아이콘과 텍스트 사이 |
| sm | 8px | 카드 내부 요소 간격 |
| md | 12px | 카드 내부 패딩 |
| lg | 16px | 카드 외부 간격, 섹션 간격 |
| xl | 24px | 섹션 간 큰 간격 |
| xxl | 32px | 화면 상단 여백 |

| 항목 | 값 |
|------|-----|
| 화면 좌우 패딩 | 16px |
| 카드 radius | 16px |
| 버튼 radius | 12px |
| 배지 radius | 8px |
| 카드 내부 패딩 | 16px |
| 리스트 아이템 높이 | 56~72px |

---

## 5. Iconography

| 카테고리 | 아이콘 스타일 |
|----------|-------------|
| 탭 바 | Outlined, 24px, 1.5px stroke |
| 카드 내 | Filled, 20px |
| 상태 | Filled, 16px |
| 네비게이션 | Outlined, 24px |

아이콘 세트: Lucide Icons 또는 SF Symbols (iOS 네이티브)

---

## 6. Stitch Design System 설정 방법

1. Stitch에서 새 프로젝트 생성
2. Design System 설정 진입
3. 위의 Colors를 하나씩 등록
4. Typography 스케일 설정
5. 설정 완료 후 화면 생성 시작

**설정 후 첫 화면(C-1 홈)을 생성하면, 이후 화면들은 이 시스템을 자동으로 따라감.**

---

*이 디자인 시스템은 Stitch 설정용이며, 추후 Figma에서 정리하여 Flutter 개발 시 ThemeData로 변환합니다.*
