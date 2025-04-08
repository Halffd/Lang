import React from 'react';
import {
  Box,
  IconButton,
  useColorModeValue,
  Divider,
  VStack,
} from 'native-base';
import { StyleSheet } from 'react-native';
import { CustomIcon } from '../CustomIcon/CustomIcon';

interface NavigationProps {
  currentPage: string;
  onNavigate: (page: string) => void;
}

const navigationStyles = StyleSheet.create({
  container: {
    width: 72,
    height: '100%',
  },
  navButton: {
    padding: 16,
  },
  active: {
    backgroundColor: 'rgba(0, 0, 0, 0.1)',
  },
  helpButton: {
    marginTop: 'auto',
  }
});

const Navigation: React.FC<NavigationProps> = ({ currentPage, onNavigate }) => {
  const bgColor = useColorModeValue('gray.50', 'gray.900');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const hoverBgColor = useColorModeValue('gray.100', 'gray.700');

  const navigationItems = [
    { id: 'search', icon: 'search' },
    { id: 'dictionary', icon: 'book' },
    { id: 'settings', icon: 'settings' },
  ];

  return (
    <Box
      h="100%"
      borderRightWidth={1}
      borderColor={borderColor}
      _web={{
        style: navigationStyles.container
      }}
    >
      <VStack space={4} py={4}>
        {navigationItems.map((item) => (
          <IconButton
            key={item.id}
            icon={<CustomIcon name={item.icon} />}
            variant="ghost"
            onPress={() => onNavigate(item.id)}
            _web={{
              style: [
                navigationStyles.navButton,
                currentPage === item.id && navigationStyles.active
              ]
            }}
            bg={currentPage === item.id ? hoverBgColor : 'transparent'}
          />
        ))}
      </VStack>

      <IconButton
        icon={<CustomIcon name="help-circle" />}
        variant="ghost"
        _web={{
          style: navigationStyles.helpButton
        }}
        bg="transparent"
        _hover={{
          bg: hoverBgColor,
        }}
      />
    </Box>
  );
};

export type { NavigationProps };
export default Navigation; 