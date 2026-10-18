import type { CSSProperties } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { PHOTO_SPOTS, type PhotoSpot } from '@/data/spots';
import { colors } from '@/theme/colors';

type SpotSheetProps = {
  selectedId: string | null;
  onSelect: (spot: PhotoSpot) => void;
};

export function SpotSheet({ selectedId, onSelect }: SpotSheetProps) {
  const insets = useSafeAreaInsets();
  const selected = PHOTO_SPOTS.find((spot) => spot.id === selectedId) ?? null;

  return (
    <View style={[styles.sheet, { paddingBottom: Math.max(insets.bottom, 16) }]}>
      <View style={styles.handleRow}>
        <View style={styles.handle} />
        <Text style={styles.title}>추천 출사지 3곳</Text>
      </View>

      <div style={listDomStyle}>
        {PHOTO_SPOTS.map((spot) => {
          const active = spot.id === selectedId;
          return (
            <button
              key={spot.id}
              type="button"
              onClick={() => onSelect(spot)}
              aria-pressed={active}
              style={{
                ...cardDomStyle,
                borderColor: active ? colors.sage : 'transparent',
                background: active ? colors.white : colors.mist,
                cursor: 'pointer',
              }}
            >
              <span
                style={{
                  display: 'block',
                  width: 10,
                  height: 10,
                  borderRadius: 5,
                  background: spot.accent,
                  marginBottom: 8,
                }}
              />
              <span style={regionDomStyle}>{spot.region}</span>
              <span style={nameDomStyle}>{spot.name}</span>
              <span style={summaryDomStyle}>{spot.summary}</span>
            </button>
          );
        })}
      </div>

      {selected ? (
        <View style={styles.detail}>
          <Text style={styles.detailLabel}>촬영 팁</Text>
          <Text style={styles.detailTime}>{selected.bestTime}</Text>
          <Text style={styles.detailTips}>{selected.tips}</Text>
        </View>
      ) : (
        <Text style={styles.hint}>지도 마커나 카드를 눌러 출사지를 선택하세요.</Text>
      )}
    </View>
  );
}

const listDomStyle: CSSProperties = {
  display: 'flex',
  gap: 12,
  overflowX: 'auto',
  paddingLeft: 16,
  paddingRight: 16,
  paddingBottom: 8,
  WebkitOverflowScrolling: 'touch',
};

const cardDomStyle: CSSProperties = {
  flex: '0 0 196px',
  width: 196,
  textAlign: 'left',
  borderRadius: 18,
  padding: 14,
  borderWidth: 1.5,
  borderStyle: 'solid',
  fontFamily: 'inherit',
};

const regionDomStyle: CSSProperties = {
  display: 'block',
  fontFamily: 'DMSans_500Medium, "DM Sans", sans-serif',
  fontSize: 11,
  letterSpacing: 0.6,
  textTransform: 'uppercase',
  color: colors.inkMuted,
};

const nameDomStyle: CSSProperties = {
  display: 'block',
  marginTop: 4,
  fontFamily: 'Fraunces_600SemiBold, Fraunces, serif',
  fontSize: 17,
  color: colors.forest,
};

const summaryDomStyle: CSSProperties = {
  display: 'block',
  marginTop: 6,
  fontFamily: 'DMSans_400Regular, "DM Sans", sans-serif',
  fontSize: 13,
  lineHeight: '18px',
  color: colors.inkMuted,
};

const styles = StyleSheet.create({
  sheet: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    zIndex: 1000,
    elevation: 1000,
    backgroundColor: colors.paper,
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    paddingTop: 10,
    borderTopWidth: 1,
    borderColor: colors.mistDeep,
  },
  handleRow: {
    alignItems: 'center',
    marginBottom: 8,
  },
  handle: {
    width: 42,
    height: 4,
    borderRadius: 999,
    backgroundColor: colors.mistDeep,
    marginBottom: 10,
  },
  title: {
    fontFamily: 'Fraunces_500Medium',
    fontSize: 18,
    color: colors.forest,
    alignSelf: 'flex-start',
    paddingHorizontal: 20,
    marginBottom: 4,
  },
  detail: {
    marginHorizontal: 16,
    marginTop: 4,
    padding: 14,
    borderRadius: 16,
    backgroundColor: colors.forest,
  },
  detailLabel: {
    fontFamily: 'DMSans_500Medium',
    fontSize: 11,
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    color: colors.sageMuted,
  },
  detailTime: {
    marginTop: 6,
    fontFamily: 'Fraunces_500Medium',
    fontSize: 16,
    color: colors.white,
  },
  detailTips: {
    marginTop: 4,
    fontFamily: 'DMSans_400Regular',
    fontSize: 13,
    lineHeight: 19,
    color: colors.mist,
  },
  hint: {
    marginHorizontal: 20,
    marginTop: 2,
    marginBottom: 4,
    fontFamily: 'DMSans_400Regular',
    fontSize: 13,
    color: colors.inkMuted,
  },
});
