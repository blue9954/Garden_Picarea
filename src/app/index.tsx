import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { BrandHeader } from '@/components/BrandHeader';
import { SpotMap } from '@/components/SpotMap';
import { SpotSheet } from '@/components/SpotSheet';
import { PHOTO_SPOTS, type PhotoSpot } from '@/data/spots';
import { colors } from '@/theme/colors';

export default function HomeScreen() {
  const [selectedId, setSelectedId] = useState<string | null>(PHOTO_SPOTS[0].id);

  const handleSelect = (spot: PhotoSpot) => {
    setSelectedId(spot.id);
  };

  return (
    <View style={styles.root}>
      <SpotMap selectedId={selectedId} onSelect={handleSelect} />
      <BrandHeader />
      <SpotSheet selectedId={selectedId} onSelect={handleSelect} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.mist,
  },
});
