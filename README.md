# Garden Picarea

서울·경기도권 추천 출사지를 지도에서 살펴보는 아이폰용 앱입니다.

## 추천 출사지 3곳

| 장소 | 권역 | 포인트 |
|------|------|--------|
| 북촌 한옥마을 | 서울 | 기와 골목 · 한옥 지붕선 |
| 반포한강공원 | 서울 | 한강 야경 · 블루아워 |
| 수원 화성 | 경기 | 성곽 석양 |

## 실행

```bash
npm install
npx expo start
```

- iPhone: Expo Go로 QR 스캔, 또는 `npx expo run:ios`
- 웹 미리보기: `npx expo start --web`

지도는 iOS에서 Apple Maps(`react-native-maps`), 웹에서는 OpenStreetMap(Leaflet)을 사용합니다.
