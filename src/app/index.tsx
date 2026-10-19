import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { BrandHeader } from '@/components/BrandHeader';
import { SpotMap } from '@/components/SpotMap';
import { SpotSheet } from '@/components/SpotSheet';
import { PHOTO_SPOTS, type PhotoSpot } from '@/data/spots';
import { colors } from '@/theme/colors';

export default function HomeScreen() {
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const handleSelect = (spot: PhotoSpot) => {
    setSelectedId(spot.id);
  };

  return (
    <View style={styles.root}>
      <View style={styles.mapLayer}>
        <SpotMap selectedId={selectedId} onSelect={handleSelect} />
      </View>
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
  mapLayer: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    zIndex: 0,
  },
});
