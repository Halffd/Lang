import React from 'react';
import { Box, Heading, Text, VStack, HStack, useColorModeValue, Pressable } from 'native-base';
import { Platform } from 'react-native';

interface CardProps {
  title: string;
  description?: string;
  onPress?: () => void;
  icon?: React.ReactNode;
  footer?: React.ReactNode;
  children?: React.ReactNode;
  mb?: number;
}

export const Card = ({ 
  title, 
  description, 
  onPress, 
  icon, 
  footer, 
  children,
  mb = 0
}: CardProps) => {
  // Use theme colors with light/dark mode support
  const bgColor = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const textColor = useColorModeValue('gray.800', 'gray.100');
  const hoverBg = useColorModeValue('gray.50', 'gray.700');
  
  const CardWrapper = onPress ? Pressable : Box;
  
  return (
    <CardWrapper
      onPress={onPress}
      width="100%"
      mb={mb}
      _hover={Platform.OS === 'web' ? {
        transform: 'translateY(-2px)',
        shadow: '2xl',
        bg: hoverBg
      } : undefined}
      transition="all 0.2s"
    >
      <Box
        bg={bgColor}
        rounded="lg"
        shadow="md"
        borderWidth={1}
        borderColor={borderColor}
        p={6}
        overflow="hidden"
      >
        <VStack space={4}>
          <HStack space={3} alignItems="center">
            {icon && (
              <Box>
                {icon}
              </Box>
            )}
            <Heading size="md" color={textColor}>
              {title}
            </Heading>
          </HStack>
          
          {description && (
            <Text color={textColor} fontSize="md" opacity={0.9}>
              {description}
            </Text>
          )}
          
          {children && (
            <Box>
              {children}
            </Box>
          )}
          
          {footer && (
            <Box pt={4} borderTopWidth={1} borderTopColor={borderColor}>
              {footer}
            </Box>
          )}
        </VStack>
      </Box>
    </CardWrapper>
  );
};

export default Card; 