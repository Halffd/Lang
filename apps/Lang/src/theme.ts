import { extendTheme } from 'native-base';

export const theme = extendTheme({
  colors: {
    primary: {
      50: '#E3F2F9',
      100: '#C5E4F3',
      200: '#A2D4EC',
      300: '#7AC1E4',
      400: '#47A9DA',
      500: '#0088CC',
      600: '#007AB8',
      700: '#006BA1',
      800: '#005885',
      900: '#003F5E',
    },
    secondary: {
      50: '#F0F7FF',
      100: '#C2E0FF',
      200: '#99CCFF',
      300: '#66B2FF',
      400: '#3399FF',
      500: '#007FFF',
      600: '#0072E6',
      700: '#0059B3',
      800: '#004C99',
      900: '#003A75',
    },
  },
  components: {
    Button: {
      defaultProps: {
        size: 'md',
        variant: 'solid',
      },
      variants: {
        solid: {
          bg: 'primary.500',
          _hover: {
            bg: 'primary.600',
          },
          _pressed: {
            bg: 'primary.700',
          },
        },
        outline: {
          borderColor: 'primary.500',
          _hover: {
            bg: 'primary.50',
          },
          _pressed: {
            bg: 'primary.100',
          },
        },
      },
    },
    Input: {
      defaultProps: {
        size: 'md',
        variant: 'outline',
      },
      variants: {
        outline: {
          borderColor: 'gray.300',
          _hover: {
            borderColor: 'primary.500',
          },
          _focus: {
            borderColor: 'primary.500',
            bg: 'transparent',
          },
        },
      },
    },
  },
  config: {
    initialColorMode: 'light',
  },
}); 