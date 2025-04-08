import React from 'react';
import { render, fireEvent } from '@testing-library/react';
import { NativeBaseProvider } from 'native-base';
import { SearchResults } from './SearchResults';

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

describe('SearchResults', () => {
  const mockResults = [
    {
      surface: '猫',
      reading: 'ねこ',
      basic: '猫',
      pos: 'noun',
      pos_detail: ['common'],
      definitions: ['cat'],
      translations: ['cat'],
      frequency: 0.8
    },
    {
      surface: '犬',
      reading: 'いぬ',
      basic: '犬',
      pos: 'noun',
      pos_detail: ['common'],
      definitions: ['dog'],
      translations: ['dog'],
      frequency: 0.7
    }
  ];

  const mockProps = {
    results: mockResults,
    isLoading: false,
    error: null,
    onSelect: jest.fn(),
    selectedResult: null
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders loading state', () => {
    const { getByText } = render(
      <SearchResults {...mockProps} isLoading={true} />,
      { wrapper: Wrapper }
    );

    expect(getByText('Analyzing text...')).toBeTruthy();
  });

  it('renders error state', () => {
    const errorMessage = 'Test error message';
    const { getByText } = render(
      <SearchResults {...mockProps} error={errorMessage} />,
      { wrapper: Wrapper }
    );

    expect(getByText(errorMessage)).toBeTruthy();
  });

  it('renders empty state', () => {
    const { getByText } = render(
      <SearchResults {...mockProps} results={[]} />,
      { wrapper: Wrapper }
    );

    expect(getByText('No results found')).toBeTruthy();
  });

  it('renders results list', () => {
    const { getByText } = render(
      <SearchResults {...mockProps} />,
      { wrapper: Wrapper }
    );

    expect(getByText('猫')).toBeTruthy();
    expect(getByText('犬')).toBeTruthy();
  });

  it('handles result selection', () => {
    const { getByText } = render(
      <SearchResults {...mockProps} />,
      { wrapper: Wrapper }
    );

    fireEvent.press(getByText('猫'));
    expect(mockProps.onSelect).toHaveBeenCalledWith(mockResults[0]);
  });

  it('highlights selected result', () => {
    const { container } = render(
      <SearchResults {...mockProps} selectedResult={mockResults[0]} />,
      { wrapper: Wrapper }
    );

    // Note: You might need to adjust this test based on your actual styling implementation
    const selectedElement = container.querySelector('.selected');
    expect(selectedElement).toBeTruthy();
  });

  it('handles scroll events', () => {
    const mockOnScroll = jest.fn();
    const { container } = render(
      <SearchResults {...mockProps} onScroll={mockOnScroll} />,
      { wrapper: Wrapper }
    );

    const scrollView = container.querySelector('ScrollView');
    fireEvent.scroll(scrollView!, { target: { scrollY: 100 } });

    expect(mockOnScroll).toHaveBeenCalled();
  });
}); 