import { useEffect, useRef } from 'react';
import { StyleSheet, View } from 'react-native';
import L from 'leaflet';
// @ts-expect-error Metro web CSS side-effect import
import 'leaflet/dist/leaflet.css';

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

function markerIcon(color: string, selected: boolean) {
  const size = selected ? 34 : 26;
  return L.divIcon({
    className: 'garden-marker',
    html: `<div style="
      width:${size}px;height:${size}px;border-radius:50%;
      background:${color};border:3px solid ${colors.white};
      box-shadow:0 4px 14px ${colors.markerRing};
      transform:translate(-50%,-50%);
    "></div>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
  });
}

export function SpotMap({ selectedId, onSelect }: SpotMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<L.Map | null>(null);
  const markersRef = useRef<Record<string, L.Marker>>({});
  const onSelectRef = useRef(onSelect);
  onSelectRef.current = onSelect;

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = L.map(containerRef.current, {
      zoomControl: false,
      attributionControl: true,
    }).setView(
      [SEOUL_GYEONGGI_REGION.latitude, SEOUL_GYEONGGI_REGION.longitude],
      10,
    );

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap',
      maxZoom: 18,
    }).addTo(map);

    PHOTO_SPOTS.forEach((spot) => {
      const marker = L.marker([spot.latitude, spot.longitude], {
        icon: markerIcon(spot.accent, false),
      }).addTo(map);

      marker.bindTooltip(spot.name, {
        direction: 'top',
        offset: [0, -12],
        opacity: 0.95,
      });

      marker.on('click', () => onSelectRef.current(spot));
      markersRef.current[spot.id] = marker;
    });

    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
      markersRef.current = {};
    };
  }, []);

  useEffect(() => {
    PHOTO_SPOTS.forEach((spot) => {
      const marker = markersRef.current[spot.id];
      if (!marker) return;
      marker.setIcon(markerIcon(spot.accent, spot.id === selectedId));
    });

    const spot = PHOTO_SPOTS.find((item) => item.id === selectedId);
    if (spot && mapRef.current) {
      mapRef.current.flyTo([spot.latitude, spot.longitude], 13, {
        duration: 0.6,
      });
    }
  }, [selectedId]);

  return (
    <View style={styles.wrap}>
      <div ref={containerRef} style={styles.mapDom} />
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    flex: 1,
  },
  mapDom: {
    width: '100%',
    height: '100%',
  } as unknown as object,
});
