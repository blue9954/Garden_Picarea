import { useEffect, useRef } from 'react';
import { StyleSheet, View } from 'react-native';
import MapView, { Marker, PROVIDER_DEFAULT } from 'react-native-maps';

import {
  PHOTO_SPOTS,
  SEOUL_GYEONGGI_REGION,
  type PhotoSpot,
} from '@/data/spots';
import { colors } from '@/theme/colors';

type SpotMapProps = {
  selectedId: string | null;
  onSelect: (spot: PhotoSpot) => void;
};

export function SpotMap({ selectedId, onSelect }: SpotMapProps) {
  const mapRef = useRef<MapView>(null);

  useEffect(() => {
    if (!mapRef.current) return;

    const spot = PHOTO_SPOTS.find((item) => item.id === selectedId);
    if (spot) {
      mapRef.current.animateToRegion(
        {
          latitude: spot.latitude,
          longitude: spot.longitude,
          latitudeDelta: 0.08,
          longitudeDelta: 0.08,
        },
        450,
      );
      return;
    }

    mapRef.current.animateToRegion(SEOUL_GYEONGGI_REGION, 450);
  }, [selectedId]);

  return (
    <View style={styles.wrap}>
      <MapView
        ref={mapRef}
        style={styles.map}
        provider={PROVIDER_DEFAULT}
        initialRegion={SEOUL_GYEONGGI_REGION}
        showsUserLocation={false}
        showsCompass={false}
        showsPointsOfInterests={false}
      >
        {PHOTO_SPOTS.map((spot) => {
          const selected = spot.id === selectedId;
          return (
            <Marker
              key={spot.id}
              coordinate={{
                latitude: spot.latitude,
                longitude: spot.longitude,
              }}
              title={spot.name}
              description={`${spot.region} · ${spot.summary}`}
              pinColor={selected ? spot.accent : colors.sage}
              onPress={() => onSelect(spot)}
            />
          );
        })}
      </MapView>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    flex: 1,
  },
  map: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
  },
});
