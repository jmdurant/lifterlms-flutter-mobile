import React from 'react';
import {View, Text, ScrollView, StyleSheet} from 'react-native';
import FocusableCard from './FocusableCard';

interface ContentRowProps {
  title: string;
  items: Array<{
    id: number;
    title: string;
    subtitle?: string;
    imageUrl?: string;
  }>;
  onItemPress: (id: number) => void;
}

const ContentRow: React.FC<ContentRowProps> = ({title, items, onItemPress}) => {
  if (items.length === 0) {
    return null;
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{title}</Text>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}>
        {items.map(item => (
          <FocusableCard
            key={item.id}
            title={item.title}
            subtitle={item.subtitle}
            imageUrl={item.imageUrl}
            onPress={() => onItemPress(item.id)}
          />
        ))}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginBottom: 40,
  },
  title: {
    color: '#FFFFFF',
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 16,
    paddingHorizontal: 60,
  },
  scrollContent: {
    paddingHorizontal: 60,
  },
});

export default ContentRow;
