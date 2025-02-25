import React from 'react';
import { HStack, IconButton, useColorModeValue, Box } from 'native-base';
import { Platform } from 'react-native';
import Icon from './CustomIcon';

interface NavigationProps {
  currentPage: string;
  onNavigate: (page: string) => void;
}

export default function Navigation({ currentPage, onNavigate }: NavigationProps) {
  const bgColor = useColorModeValue('primary.500', 'primary.700');
  const activeColor = useColorModeValue('white', 'white');
  const inactiveColor = useColorModeValue('primary.200', 'primary.300');
  
  return (
    <Box 
      bg={bgColor} 
      py={2}
      px={4}
      shadow={3}
    >
      <HStack 
        justifyContent="space-between" 
        alignItems="center"
        maxW={Platform.OS === 'web' ? "1200px" : "100%"}
        width="100%"
        alignSelf="center"
      >
        <HStack space={2}>
          <IconButton
            icon={
              <Icon 
                name="search" 
                size="md" 
                color={currentPage === 'search' ? activeColor : inactiveColor} 
              />
            }
            variant="ghost"
            _pressed={{ bg: 'primary.600' }}
            onPress={() => onNavigate('search')}
            aria-label="Search"
          />
          
          <IconButton
            icon={
              <Icon 
                name="book" 
                size="md" 
                color={currentPage === 'dictionary' ? activeColor : inactiveColor} 
              />
            }
            variant="ghost"
            _pressed={{ bg: 'primary.600' }}
            onPress={() => onNavigate('dictionary')}
            aria-label="Dictionary"
          />
        </HStack>
        
        <IconButton
          icon={
            <Icon 
              name="settings" 
              size="md" 
              color={currentPage === 'settings' ? activeColor : inactiveColor} 
            />
          }
          variant="ghost"
          _pressed={{ bg: 'primary.600' }}
          onPress={() => onNavigate('settings')}
          aria-label="Settings"
        />
      </HStack>
    </Box>
  );
} 