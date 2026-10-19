import { StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { colors } from '@/theme/colors';

export function BrandHeader() {
  const insets = useSafeAreaInsets();

  return (
    <View style={[styles.wrap, { paddingTop: insets.top + 10 }]} pointerEvents="box-none">
      <View style={styles.panel}>
        <Text style={styles.brand}>Garden Picarea</Text>
        <Text style={styles.sub}>서울 · 경기 추천 출사지</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 1000,
    paddingHorizontal: 16,
  },
  panel: {
    backgroundColor: 'rgba(244, 247, 245, 0.92)',
    borderRadius: 18,
    paddingHorizontal: 18,
    paddingVertical: 14,
    borderWidth: 1,
    borderColor: colors.mistDeep,
  },
  brand: {
    fontFamily: 'Fraunces_600SemiBold',
    fontSize: 26,
    letterSpacing: -0.4,
    color: colors.forest,
  },
  sub: {
    marginTop: 2,
    fontFamily: 'DMSans_400Regular',
    fontSize: 13,
    color: colors.inkMuted,
  },
});
