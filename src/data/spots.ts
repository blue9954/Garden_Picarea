export type PhotoSpot = {
  id: string;
  name: string;
  region: '서울' | '경기';
  latitude: number;
  longitude: number;
  summary: string;
  bestTime: string;
  tips: string;
  accent: string;
};

/** 서울·경기도권 추천 출사지 3곳 */
export const PHOTO_SPOTS: PhotoSpot[] = [
  {
    id: 'bukchon',
    name: '북촌 한옥마을',
    region: '서울',
    latitude: 37.5826,
    longitude: 126.9831,
    summary: '기와 골목과 한옥 지붕선이 겹치는 클래식 출사지.',
    bestTime: '오전 9–11시 · 황금빛 지붕',
    tips: '가회동 31번지 골목에서 광각으로 지붕 레이어를 잡아보세요.',
    accent: '#5B8A72',
  },
  {
    id: 'banpo',
    name: '반포한강공원',
    region: '서울',
    latitude: 37.5108,
    longitude: 126.9959,
    summary: '한강 수면과 서울 스카이라인이 맞닿는 야경·일몰 포인트.',
    bestTime: '일몰 전 40분 · 블루아워',
    tips: '세빛섬 방향 다리 위에서 삼각대로 장노출을 시도해보세요.',
    accent: '#3D6B8A',
  },
  {
    id: 'hwaseong',
    name: '수원 화성',
    region: '경기',
    latitude: 37.2886,
    longitude: 127.0150,
    summary: '성곽 산책로와 석양빛이 어우러지는 경기권 대표 유적 출사지.',
    bestTime: '오후 4–6시 · 서향 석양',
    tips: '서장대 쪽에서 성벽을 대각선으로 배치하면 깊이감이 살아납니다.',
    accent: '#8A6B3D',
  },
];

export const SEOUL_GYEONGGI_REGION = {
  latitude: 37.45,
  longitude: 127.0,
  latitudeDelta: 0.55,
  longitudeDelta: 0.45,
};
