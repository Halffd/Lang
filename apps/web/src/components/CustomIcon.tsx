import React from 'react';
import { Icon as NBIcon, IIconProps } from 'native-base';
import { Feather } from '@expo/vector-icons';

interface CustomIconProps extends Omit<IIconProps, 'as'> {
  name: string;
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  color?: string;
}

// Map size names to numeric values
const sizeMap = {
  xs: 16,
  sm: 20,
  md: 24,
  lg: 28,
  xl: 32,
};

export const Icon = ({ name, size = 'md', color = 'currentColor', ...props }: CustomIconProps) => {
  // Convert size name to numeric value
  const iconSize = typeof size === 'string' ? sizeMap[size] : size;

  return (
    <NBIcon
      as={Feather}
      name={name}
      size={iconSize}
      color={color}
      {...props}
    />
  );
};

export default Icon; 