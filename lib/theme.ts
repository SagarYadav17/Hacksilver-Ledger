import { useColorScheme } from 'react-native';

export const colors = {
  ink: '#182027',
  inkMuted: '#69757B',
  canvas: '#F1F7F8',
  surface: '#FFFFFF',
  surfaceAlt: '#E7EFF1',
  line: '#D9E3E6',
  primary: '#4B99B7',
  primarySoft: '#D9EDF3',
  income: '#4D9C83',
  incomeSoft: '#DDF1E8',
  expense: '#D47770',
  expenseSoft: '#F7E4E0',
  transfer: '#7889B5',
  transferSoft: '#E7EAF5',
  warning: '#B98543',
  warningSoft: '#F6EBCF',
  white: '#FFFFFF',
  black: '#000000',
};

export function useAppTheme() {
  const scheme = useColorScheme();
  const dark = scheme === 'dark';
  if (!dark) {
    return { dark: false, colors };
  }
  return {
    dark: true,
    colors: {
      ...colors,
      ink: '#EEF2F0',
      inkMuted: '#A7B5B8',
      canvas: '#151C1F',
      surface: '#202A2E',
      surfaceAlt: '#2A373B',
      line: '#3D4A4F',
      primary: '#86C6D8',
      primarySoft: '#253D44',
      income: '#8BC7AC',
      incomeSoft: '#203A31',
      expense: '#F1A09A',
      expenseSoft: '#452E2D',
      transfer: '#B3C0E4',
      transferSoft: '#31394F',
      warning: '#E1BB77',
      warningSoft: '#443923',
    },
  };
}

export const spacing = { xs: 6, sm: 10, md: 16, lg: 22, xl: 30, xxl: 40 };
export const radius = { sm: 10, md: 16, lg: 24, pill: 999 };
