import React, {useRef, useState} from 'react';
import {
  TouchableOpacity,
  View,
  Text,
  Image,
  StyleSheet,
  Animated,
} from 'react-native';

interface FocusableCardProps {
  title: string;
  subtitle?: string;
  imageUrl?: string;
  onPress: () => void;
  width?: number;
  height?: number;
}

const FocusableCard: React.FC<FocusableCardProps> = ({
  title,
  subtitle,
  imageUrl,
  onPress,
  width = 300,
  height = 200,
}) => {
  const scale = useRef(new Animated.Value(1)).current;
  const [isFocused, setIsFocused] = useState(false);

  const handleFocus = () => {
    setIsFocused(true);
    Animated.spring(scale, {
      toValue: 1.08,
      friction: 4,
      useNativeDriver: true,
    }).start();
  };

  const handleBlur = () => {
    setIsFocused(false);
    Animated.spring(scale, {
      toValue: 1,
      friction: 4,
      useNativeDriver: true,
    }).start();
  };

  return (
    <TouchableOpacity
      onPress={onPress}
      onFocus={handleFocus}
      onBlur={handleBlur}
      activeOpacity={0.9}>
      <Animated.View
        style={[
          styles.card,
          {width, height, transform: [{scale}]},
          isFocused && styles.cardFocused,
        ]}>
        {imageUrl ? (
          <Image
            source={{uri: imageUrl}}
            style={styles.image}
            resizeMode="cover"
          />
        ) : (
          <View style={styles.placeholder}>
            <Text style={styles.placeholderIcon}>📚</Text>
          </View>
        )}
        <View style={styles.overlay}>
          <Text style={styles.title} numberOfLines={2}>
            {title}
          </Text>
          {subtitle && (
            <Text style={styles.subtitle} numberOfLines={1}>
              {subtitle}
            </Text>
          )}
        </View>
      </Animated.View>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  card: {
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#1e1e1e',
    marginRight: 20,
    marginBottom: 10,
  },
  cardFocused: {
    borderWidth: 3,
    borderColor: '#4FC3F7',
    shadowColor: '#4FC3F7',
    shadowOffset: {width: 0, height: 0},
    shadowOpacity: 0.5,
    shadowRadius: 15,
    elevation: 10,
  },
  image: {
    width: '100%',
    height: '100%',
    position: 'absolute',
  },
  placeholder: {
    width: '100%',
    height: '100%',
    position: 'absolute',
    backgroundColor: '#2a2a2a',
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderIcon: {
    fontSize: 48,
  },
  overlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    padding: 16,
    backgroundColor: 'rgba(0,0,0,0.7)',
  },
  title: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '700',
  },
  subtitle: {
    color: '#B0B0B0',
    fontSize: 14,
    marginTop: 4,
  },
});

export default FocusableCard;
