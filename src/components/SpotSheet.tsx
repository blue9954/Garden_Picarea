import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, { FadeInDown, FadeInUp, LinearTransition } from 'react-native-reanimated';

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

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.list}
      >
        {PHOTO_SPOTS.map((spot, index) => {
          const active = spot.id === selectedId;
          return (
            <Animated.View
              key={spot.id}
              entering={FadeInDown.delay(120 + index * 80).duration(420)}
              layout={LinearTransition}
            >
              <Pressable
                onPress={() => onSelect(spot)}
                style={({ pressed }) => [
                  styles.card,
                  active && styles.cardActive,
                  pressed && styles.cardPressed,
                ]}
                accessibilityRole="button"
                accessibilityState={{ selected: active }}
                accessibilityLabel={`${spot.name}, ${spot.region}`}
              >
                <View style={[styles.dot, { backgroundColor: spot.accent }]} />
                <Text style={styles.cardRegion}>{spot.region}</Text>
                <Text style={styles.cardName}>{spot.name}</Text>
                <Text style={styles.cardSummary} numberOfLines={2}>
                  {spot.summary}
                </Text>
              </Pressable>
            </Animated.View>
          );
        })}
      </ScrollView>

      {selected ? (
        <Animated.View
          key={selected.id}
          entering={FadeInUp.duration(320)}
          style={styles.detail}
        >
          <Text style={styles.detailLabel}>촬영 팁</Text>
          <Text style={styles.detailTime}>{selected.bestTime}</Text>
          <Text style={styles.detailTips}>{selected.tips}</Text>
        </Animated.View>
      ) : (
        <Text style={styles.hint}>지도 마커나 카드를 눌러 출사지를 선택하세요.</Text>
      )}
    </View>
  );
}

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
  list: {
    paddingHorizontal: 16,
    gap: 12,
    paddingBottom: 8,
  },
  card: {
    width: 196,
    backgroundColor: colors.mist,
    borderRadius: 18,
    padding: 14,
    borderWidth: 1.5,
    borderColor: 'transparent',
  },
  cardActive: {
    borderColor: colors.sage,
    backgroundColor: colors.white,
  },
  cardPressed: {
    opacity: 0.88,
  },
  dot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginBottom: 8,
  },
  cardRegion: {
    fontFamily: 'DMSans_500Medium',
    fontSize: 11,
    letterSpacing: 0.6,
    textTransform: 'uppercase',
    color: colors.inkMuted,
  },
  cardName: {
    marginTop: 4,
    fontFamily: 'Fraunces_600SemiBold',
    fontSize: 17,
    color: colors.forest,
  },
  cardSummary: {
    marginTop: 6,
    fontFamily: 'DMSans_400Regular',
    fontSize: 13,
    lineHeight: 18,
    color: colors.inkMuted,
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
