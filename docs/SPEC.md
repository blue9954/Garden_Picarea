# Garden Picarea 작업명세서 (v0.1)

> 브랜드: **Garden** · 제품: **Picarea** (Picture + Area) · 플랫폼: **iPhone 네이티브 (Swift / SwiftUI)**
> 작성일: 2026-10-24

## 1. 제품 개요

SNS와 인터넷 커뮤니티(블로그·카페)에서 사람들이 실제로 많이 찍고 이야기하는 장소를 찾아,
**지금 시간·날씨·계절**에 맞는 순서로 출사지를 추천하는 iPhone 앱.

| 구분 | 역할 |
| --- | --- |
| **후보 발굴 (검색)** | SNS·커뮤니티 게시글에서 장소명 추출 → 언급량/최신성/출처 다양성으로 점수화 |
| **정렬 보정 (추천)** | 계절 테마 일치, 골든아워/블루아워까지 남은 시간, 현재 날씨 적합도 |

### 1.1 확정 사항
- iPhone 네이티브 (iOS 17+, Swift 6, SwiftUI, MapKit)
- 검색 데이터: SNS / 인터넷 커뮤니티 기반
- "Garden"은 브랜드명 → 번들 ID `com.garden.picarea`, 앱 표시 이름 `Picarea`

### 1.2 가정 (변경 가능 — 피드백 주세요)
| # | 가정 | 이유 |
| --- | --- | --- |
| A1 | 이전에 정한 "시간·날씨·계절"은 **정렬 보정 요소**로 유지 | 마지막 요청이 "검색할 때" 커뮤니티 기반이라고 한정했기 때문 |
| A2 | 날씨는 공공데이터 대신 **Apple WeatherKit** | 네이티브라 연동이 가장 간단함. 프로토콜로 추상화해 기상청 API로 교체 가능 |
| A3 | 일출·일몰은 **기기 내 천문 계산 (NOAA 알고리즘)** | 네트워크·키 불필요, 오프라인 동작 |
| A4 | 앱 표시 이름은 `Picarea` | 브랜드(Garden)와 제품명 분리 |
| A5 | 1차 대상 지역은 대한민국 | 커뮤니티 API(네이버/카카오)가 한국 중심 |

## 2. 데이터 소스

| 소스 | API | 용도 | 상태 |
| --- | --- | --- | --- |
| 네이버 블로그 | `openapi.naver.com/v1/search/blog.json` | 게시글 (제목, 요약, 작성일) | **MVP** |
| 네이버 카페 | `openapi.naver.com/v1/search/cafearticle.json` | 커뮤니티 게시글 | **MVP** |
| 다음 블로그 | `dapi.kakao.com/v2/search/blog` | 게시글 (작성일시 포함) | **MVP** |
| 다음 카페 | `dapi.kakao.com/v2/search/cafe` | 커뮤니티 게시글 | **MVP** |
| 카카오 로컬 | `dapi.kakao.com/v2/local/search/keyword.json` | 추출한 장소명 실존 검증 + 좌표 | **MVP** |
| Instagram | Graph API Hashtag Search | 해시태그 게시물 | Phase 2 (비즈니스 계정·앱 심사 필요) |
| YouTube | Data API v3 search | 출사 브이로그 | Phase 2 |

**원칙:**
- 공식 API만 사용합니다. 스크래핑은 하지 않습니다 (Instagram 등 약관 위반 위험).
- 원문 제목·요약·링크와 출처만 표시합니다. 이미지는 재호스팅하지 않습니다.
- 사용량 한도: 네이버 25,000회/일. 카카오는 앱별 쿼터를 따릅니다. 응답은 캐시(TTL)해서 호출을 아낍니다.

## 3. 추천 파이프라인

```
검색어("제주 수국")
  └─ QueryBuilder ── "제주 수국 출사", "제주 수국 사진 명소", ...
       └─ CommunitySearchProvider × N (병렬, 개별 실패 허용)
            └─ Normalizer (HTML 태그·엔티티 제거, URL 중복 제거)
                 └─ SpotExtractor (2단계: 시드 발굴 → 본문 전파 집계, 아래 3.0)
                      └─ MentionAggregator (언급 수, 출처 다양성, 최신성, 계절 일치 언급 비율)
                           └─ PlaceVerifier (카카오 로컬로 상위 N개 검증 → 좌표)
                                └─ ContextScorer (계절·시간·날씨)
                                     └─ RecommendationEngine → 정렬된 [Recommendation]
```

### 3.0 장소명 추출 (SpotExtractor)
실제 출사지 이름은 "보롬왓", "혼인지", "카멜리아힐"처럼 접미사가 없는 경우가 많아서 2단계로 추출합니다.

1. **시드 발굴**: 아래 패턴 중 하나에 걸리면 후보가 됩니다.
   - 해시태그: `#보롬왓`
   - 장소 접미사 + 조사·단어 경계: `함덕해수욕장에서`, `새별오름은`. 경계를 확인하지 않으면 "…에서 사진"의 "사"가 접미사로 오인됩니다.
   - 테마어·사진어 바로 앞 단어: `혼인지 수국`, `안반데기 은하수`. 용언 활용형(찍은, 따라)은 제외합니다.
   - 3개 이상 나열: `보롬왓, 휴애리, 혼인지`
   - 괄호·따옴표: 안의 내용이 접미사로 끝날 때만 인정합니다.
2. **전파 집계**: 시드 이름이 다른 글 본문에 단어로 나오면 언급으로 셉니다. 지역 접두어와 조사는 허용합니다.
3. **정제**: 지역 접두어를 분리해 검증용 힌트로 씁니다 (`제주새별오름` → `새별오름` + 제주). 일반어, 테마어 단독, `수국길` 같은 테마어+접미사, 날짜 표현은 버립니다.
4. **검증**: 카카오 로컬로 실존 여부를 확인합니다. 정확히 일치하지 않으면 관광·자연 카테고리일 때만 인정하고, 주차장·음식점 등은 제외합니다. 같은 장소로 확인된 후보는 하나로 합칩니다.

### 3.1 점수 공식 (0~1 정규화)
```
community = 0.6·log(1+mentions)/log(1+maxMentions) + 0.25·sourceDiversity + 0.15·recency
season    = 0.6·seasonalMentionRatio + 0.4·themeSeasonMatch
time      = 테마별 시간대 적합도 (골든아워 테마: 남은 시간이 짧을수록 ↑ / 야경·은하수: 일몰 이후 ↑)
weather   = 테마 × 하늘상태 적합도 표 (예: 은하수·맑음=1.0, 운해·안개=0.9, 대부분·비=0.2)

total = 0.50·community + 0.25·season + 0.15·weather + 0.10·time
```
- `seasonalMentionRatio`: 연도와 상관없이 **오늘 날짜 기준 ±30일 안에 작성된 언급의 비율**입니다. 예를 들어 작년 4월에 많이 언급된 벚꽃 명소는 올해 4월에 점수가 올라갑니다.
- `recency`: 반감기 365일 지수 감쇠 평균입니다.
- 가중치는 `ScoringWeights`로 조절할 수 있습니다.

## 4. 아키텍처

```
Garden_Picarea/
├─ Packages/GardenCore/          ← 플랫폼 독립 Swift Package (Linux에서도 빌드·테스트)
│   ├─ Sources/GardenCore/
│   │   ├─ Models/               Spot, Mention, Recommendation, Theme, Season, SkyCondition
│   │   ├─ Networking/           HTTPClient 프로토콜, URLSessionHTTPClient, GardenError
│   │   ├─ Providers/            NaverSearchProvider, KakaoSearchProvider, KakaoPlaceVerifier
│   │   ├─ Processing/           TextNormalizer, QueryBuilder, SpotExtractor, MentionAggregator
│   │   ├─ Context/              SolarCalculator, SeasonResolver, ContextScorer, WeatherProvider
│   │   └─ Engine/               RecommendationEngine, ResponseCache
│   └─ Tests/GardenCoreTests/    Swift Testing + JSON 픽스처 + MockHTTPClient
├─ App/                          ← SwiftUI 앱 (Mac + Xcode에서 빌드)
│   ├─ Sources/                  PicareaApp, Views, ViewModels, WeatherKitProvider, LocationService
│   ├─ Resources/                Info.plist, Assets
│   └─ Config/                   Secrets.example.xcconfig (실제 Secrets.xcconfig는 gitignore)
├─ project.yml                   XcodeGen 정의 (`xcodegen generate`로 .xcodeproj 생성)
├─ Tools/AppLogicHarness/        App의 ViewModel·설정 코드(심볼릭 링크)를 Linux에서 컴파일·테스트
├─ scripts/test-linux.sh         Docker swift 이미지로 GardenCore 테스트 실행
├─ scripts/test-app-logic.sh     앱 로직 하네스 실행
└─ .github/workflows/ci.yml      Linux 테스트 (+ macOS 앱 빌드 잡)
```

- **MVVM과 Observation:** ViewModel은 `@Observable @MainActor`입니다. 새 검색이 시작되면 이전 `Task`를 취소합니다.
- **의존성 주입:** Provider, Weather, Clock을 프로토콜로 주입해서 테스트할 때 전부 Mock으로 바꿀 수 있습니다.
- **동시성:** Swift 6 strict concurrency를 적용하고, 모든 모델은 `Sendable`입니다. Provider 호출은 `TaskGroup`으로 병렬 처리합니다.

## 5. 화면 구성 (SwiftUI)

| 화면 | 구성 |
| --- | --- |
| **홈** | 현재 계절 배너, 오늘 골든아워/블루아워 카운트다운, 테마 칩(벚꽃·수국·단풍·설경·야경·은하수·일출·일몰), "지금 추천" 리스트 |
| **검색** | 검색창(지역 + 테마), 결과 카드(장소명, 종합 점수, 언급 N건, 출처 아이콘, 계절/날씨 배지) |
| **상세** | MapKit 지도 핀, 일출·일몰·골든아워 시각, 현재 날씨, 커뮤니티 언급 목록(탭하면 Safari 원문), 길찾기(Apple 지도) |
| **설정** | API 키 연결 상태, 사용할 출처 on/off, 점수 가중치 프리셋 |

## 6. 에러 처리 (방어적 설계)

| 상황 | 처리 |
| --- | --- |
| API 키 없음 / 401 | 해당 Provider만 비활성화하고 설정 화면으로 안내 |
| 429 / 쿼터 초과 | 해당 Provider를 쿨다운(지수 백오프)하고 캐시 결과를 우선 사용 |
| 네트워크 끊김 / 타임아웃 | 부분 결과를 표시하고 상단에 "일부 출처를 불러오지 못했어요" 배너 |
| JSON 스키마 변경 | 디코딩 실패를 Provider 단위로 격리 (전체 크래시 금지), 선택 필드는 optional |
| 검색 취소 | `CancellationError`는 에러로 표시하지 않음 |
| 위치 권한 거부 | 검색어 기반 모드로 동작하고 서울을 기본 좌표로 사용 |
| WeatherKit 실패 | weather 점수를 중립값(0.5)으로 처리 |

## 7. 보안
- 키는 `Secrets.xcconfig` → Info.plist 변수로 주입하고 저장소에 커밋하지 않습니다.
- ⚠️ 클라이언트에 넣은 키는 앱을 분석하면 추출될 수 있습니다. 출시 전에 **경량 프록시 서버**(Phase 2: Cloudflare Workers 등)로 옮겨야 합니다. `HTTPClient` 추상화 덕분에 엔드포인트만 바꾸면 됩니다.

## 8. 테스트 하네스
| 레벨 | 대상 | 실행 환경 |
| --- | --- | --- |
| 단위 | SolarCalculator(독립 구현 astral 참조값 대비 ±90초), SeasonalCalendar, TextNormalizer, SpotExtractor, 점수 공식 | Linux(Docker) / macOS |
| 통합 (Mock) | 픽스처 JSON → Provider → Engine 전 구간, 부분 실패·401·429 시나리오 | Linux / macOS |
| 앱 로직 | SearchViewModel(자동 검색, 질의 조합, 이전 검색 취소, 상태 전이), AppConfiguration | Linux(하네스) / macOS |
| 실 API 스모크 | 환경변수 `NAVER_CLIENT_ID` 등이 있을 때만 실행 | 로컬 |
| UI | SwiftUI Preview, XCUITest | macOS (Xcode) |

## 9. 마일스톤
| 단계 | 내용 | 상태 |
| --- | --- | --- |
| M0 | 작업명세서 | ✅ 이 문서 |
| M1 | GardenCore: 모델, 텍스트 처리, 장소 추출, 천문/계절/점수, Provider, Engine, 테스트 | ✅ 테스트 53개 통과 (Linux, Swift 6.2) |
| M2 | SwiftUI 앱 골격: 홈/검색/상세/설정, WeatherKit, 위치, XcodeGen | ✅ 작성 완료 · 로직 하네스 9개 통과 · ⏳ Xcode 빌드 미검증 |
| M3 | 실 API 키로 검증, 추출 정확도 튜닝 (불용어·접미사 사전 확장) | 키 필요 |
| M4 | 즐겨찾기, 디스크 캐시, 위젯(오늘의 골든아워) | 예정 |
| M5 | 프록시 서버, Instagram/YouTube 연동, 사용자 제보 | 예정 |

## 10. 제약
- 이 클라우드 작업 환경은 Linux라서 **iOS 앱 타깃(SwiftUI/MapKit/WeatherKit)은 빌드하거나 실행할 수 없습니다.** 로직은 전부 GardenCore에 두고 Linux에서 테스트합니다. 앱 빌드는 Mac에서 `xcodegen generate` 후 Xcode로 하거나 CI의 macOS 잡에서 확인합니다.
- WeatherKit을 쓰려면 Apple Developer 계정과 App ID에 WeatherKit capability가 있어야 합니다.
