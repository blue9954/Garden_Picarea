# Garden_Picarea

**Garden** 브랜드의 출사지 추천 iPhone 앱 **Picarea**입니다.
SNS와 인터넷 커뮤니티(네이버·다음 블로그/카페)에서 사람들이 실제로 찍고 이야기하는 장소를 찾고,
**지금의 계절·날씨·시간(골든아워)**에 맞춰 순위를 매깁니다.

- 작업명세서: [`docs/SPEC.md`](docs/SPEC.md)

## 구조
| 경로 | 내용 |
| --- | --- |
| `Packages/GardenCore` | 플랫폼 독립 로직 (검색 Provider, 장소 추출, 천문 계산, 점수, 엔진). Linux/macOS에서 테스트 |
| `App/` | SwiftUI 앱 (홈·검색·상세·설정, WeatherKit, CoreLocation) |
| `Tools/AppLogicHarness` | 앱 ViewModel·설정 코드를 Linux에서 컴파일·테스트하는 하네스 |
| `project.yml` | XcodeGen 프로젝트 정의 |

## 시작하기 (Mac)
```bash
brew install xcodegen
cp App/Config/Secrets.example.xcconfig App/Config/Secrets.xcconfig   # API 키 입력
xcodegen generate
open Picarea.xcodeproj
```
API 키 발급 경로:
- [네이버 개발자센터](https://developers.naver.com/apps): 애플리케이션을 등록하고 "검색" API를 선택합니다.
- [카카오 developers](https://developers.kakao.com/console/app): REST API 키를 발급하고 "카카오맵(로컬)" 사용을 설정합니다.
- WeatherKit은 Apple Developer에서 App ID에 capability를 켠 뒤 `WEATHERKIT_ENABLED = YES`로 바꿉니다.

## 테스트
```bash
./scripts/test-linux.sh       # GardenCore (Docker swift:6.2 또는 로컬 swift)
./scripts/test-app-logic.sh   # 앱 ViewModel·설정 하네스
# 실제 API 스모크 테스트 (키가 있을 때만 실행)
NAVER_CLIENT_ID=… NAVER_CLIENT_SECRET=… KAKAO_REST_API_KEY=… ./scripts/test-linux.sh --filter LiveSmoke
```
CI(`.github/workflows/ci.yml`): Linux에서 두 테스트를 실행하고, macOS에서 iOS 시뮬레이터용으로 앱을 빌드합니다.
