import { Icon, IIconProps } from 'native-base';
import React from 'react';
import { StyleSheet, ViewStyle } from 'react-native';
import { Feather } from '@expo/vector-icons';

export interface CustomIconProps extends Omit<IIconProps, 'as'> {
  name: string;
  size?: number;
  color?: string;
}

const styles = StyleSheet.create({
  icon: {
    display: 'flex' as const,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  }
});

export const CustomIcon: React.FC<CustomIconProps> = ({
  name,
  size = 24,
  color,
  ...props
}) => {
  return (
    <Icon
      as={Feather}
      name={name}
      size={size}
      color={color}
      _web={{
        style: styles.icon as ViewStyle
      }}
      {...props}
    />
  );
};

export default CustomIcon; 