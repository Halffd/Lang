import React from 'react';
import {
  Box,
  Heading,
  Text,
  VStack,
  HStack,
  useColorModeValue,
  Pressable,
} from 'native-base';
import { ViewStyle, TextStyle, StyleSheet } from 'react-native';

export interface CardProps {
  title: string;
  description?: string;
  icon?: React.ReactNode;
  children?: React.ReactNode;
  footer?: React.ReactNode;
  onPress?: () => void;
  mb?: number;
}

const cardStyles = StyleSheet.create({
  card: {
    backfaceVisibility: 'hidden' as const,
  },
  interactive: {
    cursor: 'pointer' as const,
  },
  icon: {
    marginRight: 12,
  },
  content: {
    marginTop: 16,
  },
  footer: {
    marginTop: 24,
    paddingTop: 24,
  }
});

export const Card: React.FC<CardProps> = ({
  title,
  description,
  icon,
  children,
  footer,
  onPress,
  mb = 4,
}) => {
  const bgColor = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const textColor = useColorModeValue('gray.800', 'white');
  const subTextColor = useColorModeValue('gray.600', 'gray.400');
  const hoverBgColor = useColorModeValue('gray.50', 'gray.700');

  const content = (
    <Box
      bg={bgColor}
      borderWidth={1}
      borderColor={borderColor}
      borderRadius="lg"
      p={6}
      mb={mb}
      _web={{
        style: [
          cardStyles.card,
          onPress && cardStyles.interactive
        ] as ViewStyle[]
      }}
    >
      <HStack space={3} alignItems="center">
        {icon && (
          <Box _web={{ style: cardStyles.icon as ViewStyle }}>
            {icon}
          </Box>
        )}
        <Box flex={1}>
          <Heading
            size="md"
            color={textColor}
          >
            {title}
          </Heading>
          {description && (
            <Text
              color={subTextColor}
              fontSize="sm"
            >
              {description}
            </Text>
          )}
        </Box>
      </HStack>

      {children && (
        <Box _web={{ style: cardStyles.content as ViewStyle }}>
          {children}
        </Box>
      )}

      {footer && (
        <Box
          mt={6}
          pt={6}
          borderTopWidth={1}
          borderColor={borderColor}
          _web={{ style: cardStyles.footer as ViewStyle }}
        >
          {footer}
        </Box>
      )}
    </Box>
  );

  if (onPress) {
    return (
      <Pressable
        onPress={onPress}
        _hover={{
          bg: hoverBgColor,
          shadow: 'md',
        }}
      >
        {content}
      </Pressable>
    );
  }

  return content;
};

export default Card; 