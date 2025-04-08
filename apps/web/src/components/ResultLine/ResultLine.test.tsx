import React from 'react';
import { render, fireEvent } from '@testing-library/react';
import { NativeBaseProvider } from 'native-base';
import { ResultLine } from './ResultLine';
import type { TokenizedWord } from '../../types';

// Create a custom wrapper with NativeBase provider
const inset = {
  frame: { x: 0, y: 0, width: 0, height: 0 },
  insets: { top: 0, right: 0, bottom: 0, left: 0 },
};

const Wrapper = ({ children }: { children: React.ReactNode }) => (
  <NativeBaseProvider initialWindowMetrics={inset}>
    {children}
  </NativeBaseProvider>
);

describe('ResultLine', () => {
  const mockWord: TokenizedWord = {
    surface: '猫',
    reading: 'ねこ',
    basic: '猫',
    pos: 'noun',
    pos_detail: ['common', 'animal'],
    definitions: ['cat', 'feline'],
    translations: ['cat'],
    frequency: 0.85
  };

  const mockProps = {
    word: mockWord,
    onSelect: jest.fn(),
    isSelected: false
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders basic word information correctly', () => {
    const { getByText } = render(
      <ResultLine {...mockProps} />,
      { wrapper: Wrapper }
    );

    expect(getByText('猫')).toBeTruthy();
    expect(getByText('ねこ')).toBeTruthy();
    expect(getByText('noun')).toBeTruthy();
  });

  it('renders all part of speech details', () => {
    const { getByText } = render(
      <ResultLine {...mockProps} />,
      { wrapper: Wrapper }
    );

    mockWord.pos_detail.forEach(detail => {
      expect(getByText(detail)).toBeTruthy();
    });
  });

  it('renders definitions correctly', () => {
    const { getByText } = render(
      <ResultLine {...mockProps} />,
      { wrapper: Wrapper }
    );

    expect(getByText('cat; feline')).toBeTruthy();
  });

  it('renders frequency percentage', () => {
    const { getByText } = render(
      <ResultLine {...mockProps} />,
      { wrapper: Wrapper }
    );

    expect(getByText('85%')).toBeTruthy();
  });

  it('applies selected styles when isSelected is true', () => {
    const { container } = render(
      <ResultLine {...mockProps} isSelected={true} />,
      { wrapper: Wrapper }
    );

    expect(container.querySelector('.selected')).toBeTruthy();
  });

  it('handles click events', () => {
    const { container } = render(
      <ResultLine {...mockProps} />,
      { wrapper: Wrapper }
    );

    const pressable = container.querySelector('.container');
    fireEvent.click(pressable!);

    expect(mockProps.onSelect).toHaveBeenCalledTimes(1);
  });

  it('renders without reading when not provided', () => {
    const wordWithoutReading = {
      ...mockWord,
      reading: undefined
    };

    const { queryByText } = render(
      <ResultLine {...mockProps} word={wordWithoutReading} />,
      { wrapper: Wrapper }
    );

    expect(queryByText('ねこ')).toBeNull();
  });

  it('renders without frequency when not provided', () => {
    const wordWithoutFrequency = {
      ...mockWord,
      frequency: undefined
    };

    const { queryByText } = render(
      <ResultLine {...mockProps} word={wordWithoutFrequency} />,
      { wrapper: Wrapper }
    );

    expect(queryByText('85%')).toBeNull();
  });

  it('handles empty definitions array', () => {
    const wordWithoutDefinitions = {
      ...mockWord,
      definitions: []
    };

    const { container } = render(
      <ResultLine {...mockProps} word={wordWithoutDefinitions} />,
      { wrapper: Wrapper }
    );

    expect(container.querySelector('.definitions')).toBeNull();
  });

  it('handles hover state', () => {
    const { container } = render(
      <ResultLine {...mockProps} />,
      { wrapper: Wrapper }
    );

    const element = container.querySelector('.container')!;
    fireEvent.mouseEnter(element);
    expect(element).toHaveStyle({ backgroundColor: 'gray.50' });
    
    fireEvent.mouseLeave(element);
    expect(element).not.toHaveStyle({ backgroundColor: 'gray.50' });
  });
}); 