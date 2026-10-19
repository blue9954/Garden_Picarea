import { Pressable, StyleSheet, Text, View } from 'react-native';

import type { PhotoSpot } from '@/data/spots';
import { colors } from '@/theme/colors';

type SpotCardProps = {
  spot: PhotoSpot;
  active: boolean;
  onSelect: (spot: PhotoSpot) => void;
};

export function SpotCard({ spot, active, onSelect }: SpotCardProps) {
  return (
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
  );
}

const styles = StyleSheet.create({
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
});
