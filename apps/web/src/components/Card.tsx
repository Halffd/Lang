import React from 'react';
import { Box, Heading, Text, VStack, HStack, Icon, useColorModeValue } from 'native-base';
import { TouchableOpacity } from 'react-native';

interface CardProps {
  title: string;
  description?: string;
  onPress?: () => void;
  icon?: React.ReactNode;
  footer?: React.ReactNode;
  children?: React.ReactNode;
}

export const Card = ({ 
  title, 
  description, 
  onPress, 
  icon, 
  footer, 
  children 
}: CardProps) => {
  // Use theme colors with light/dark mode support
  const bgColor = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const textColor = useColorModeValue('gray.800', 'gray.100');
  
  const CardContainer = onPress ? TouchableOpacity : Box;
  
  return (
    <CardContainer
      onPress={onPress}
      width="100%"
    >
      <Box
        bg={bgColor}
        rounded="lg"
        shadow={2}
        borderWidth={1}
        borderColor={borderColor}
        p={4}
        mb={4}
      >
        <VStack space={3}>
          <HStack space={2} alignItems="center">
            {icon && (
              <Box mr={2}>
                {icon}
              </Box>
            )}
            <Heading size="md" color={textColor}>
              {title}
            </Heading>
          </HStack>
          
          {description && (
            <Text color={textColor} opacity={0.8}>
              {description}
            </Text>
          )}
          
          {children && (
            <Box mt={2}>
              {children}
            </Box>
          )}
          
          {footer && (
            <Box mt={3} pt={3} borderTopWidth={1} borderTopColor={borderColor}>
              {footer}
            </Box>
          )}
        </VStack>
      </Box>
    </CardContainer>
  );
};

export default Card; 