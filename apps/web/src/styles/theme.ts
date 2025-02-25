import { extendTheme } from 'native-base';
import scssVars from './main.scss';

// Create a theme that works across platforms
export const theme = extendTheme({
  colors: {
    primary: {
      50: '#e3f2fd',
      100: '#bbdefb',
      200: '#90caf9',
      300: '#64b5f6',
      400: '#42a5f5',
      500: scssVars['primaryColor'] || '#3498db',
      600: '#1e88e5',
      700: '#1976d2',
      800: '#1565c0',
      900: '#0d47a1',
    },
    secondary: {
      50: '#e8f5e9',
      100: '#c8e6c9',
      200: '#a5d6a7',
      300: '#81c784',
      400: '#66bb6a',
      500: scssVars['secondaryColor'] || '#2ecc71',
      600: '#43a047',
      700: '#388e3c',
      800: '#2e7d32',
      900: '#1b5e20',
    },
    error: {
      500: scssVars['errorColor'] || '#e74c3c',
    },
    success: {
      500: scssVars['successColor'] || '#27ae60',
    },
    warning: {
      500: scssVars['warningColor'] || '#f39c12',
    },
    info: {
      500: scssVars['infoColor'] || '#3498db',
    },
    text: {
      primary: scssVars['textColor'] || '#2c3e50',
    },
    background: {
      default: scssVars['backgroundColor'] || '#f5f6fa',
    },
  },
  fontSizes: {
    xs: '12px',
    sm: '14px',
    md: '16px',
    lg: '18px',
    xl: '24px',
    '2xl': '32px',
  },
  space: {
    xs: '4px',
    sm: '8px',
    md: '16px',
    lg: '24px',
    xl: '32px',
    '2xl': '48px',
  },
  config: {
    // Changing initialColorMode to 'light'
    initialColorMode: 'light',
  },
});

// For TypeScript
type CustomThemeType = typeof theme;

declare module 'native-base' {
  interface ICustomTheme extends CustomThemeType {}
}

export default theme; 