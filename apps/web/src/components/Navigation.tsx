import React from 'react';
import { StyleSheet, View, Text, TouchableOpacity, Platform } from 'react-native';

interface NavigationProps {
  currentPage: string;
  onNavigate: (page: string) => void;
}

export default function Navigation({ currentPage, onNavigate }: NavigationProps) {
  return (
    <View style={styles.header}>
      <View style={styles.titleContainer}>
        <Text style={styles.title}>Lang</Text>
      </View>
      
      <View style={styles.nav}>
        <TouchableOpacity
          style={[styles.navItem, currentPage === 'search' && styles.navItemActive]}
          onPress={() => onNavigate('search')}
        >
          <Text style={[styles.navText, currentPage === 'search' && styles.navTextActive]}>
            Search
          </Text>
        </TouchableOpacity>
        
        <TouchableOpacity
          style={[styles.navItem, currentPage === 'settings' && styles.navItemActive]}
          onPress={() => onNavigate('settings')}
        >
          <Text style={[styles.navText, currentPage === 'settings' && styles.navTextActive]}>
            Settings
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    backgroundColor: '#4a90e2',
    paddingTop: Platform.OS === 'web' ? 16 : 48,
    paddingBottom: 16,
    paddingHorizontal: 16,
  },
  titleContainer: {
    marginBottom: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
  },
  nav: {
    flexDirection: 'row',
    gap: 16,
  },
  navItem: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 20,
  },
  navItemActive: {
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
  },
  navText: {
    color: 'rgba(255, 255, 255, 0.8)',
    fontSize: 16,
    fontWeight: '500',
  },
  navTextActive: {
    color: '#fff',
    fontWeight: '600',
  },
}); 