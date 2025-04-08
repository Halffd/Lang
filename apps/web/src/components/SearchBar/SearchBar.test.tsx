import React from 'react';
import { render, fireEvent, act } from '@testing-library/react';
import { NativeBaseProvider } from 'native-base';
import { SearchBar } from './SearchBar';

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

describe('SearchBar', () => {
  const mockProps = {
    inputText: '',
    onInputChange: jest.fn(),
    onSearch: jest.fn(),
    onHistorySelect: jest.fn(),
    history: [
      { text: 'test search 1', timestamp: Date.now() },
      { text: 'test search 2', timestamp: Date.now() - 1000 }
    ],
    showHistory: false
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders correctly', () => {
    const { getByPlaceholderText, getByRole } = render(
      <SearchBar {...mockProps} />,
      { wrapper: Wrapper }
    );

    expect(getByPlaceholderText('Search in Japanese or English...')).toBeTruthy();
    expect(getByRole('button', { name: 'Search' })).toBeTruthy();
  });

  it('handles input changes', () => {
    const { getByPlaceholderText } = render(
      <SearchBar {...mockProps} />,
      { wrapper: Wrapper }
    );

    const input = getByPlaceholderText('Search in Japanese or English...');
    fireEvent.changeText(input, 'test');

    expect(mockProps.onInputChange).toHaveBeenCalledWith('test');
  });

  it('handles search submission', () => {
    const { getByRole } = render(
      <SearchBar {...mockProps} inputText="test" />,
      { wrapper: Wrapper }
    );

    const searchButton = getByRole('button', { name: 'Search' });
    fireEvent.press(searchButton);

    expect(mockProps.onSearch).toHaveBeenCalledWith('test');
  });

  it('shows history when showHistory is true', () => {
    const { getByText } = render(
      <SearchBar {...mockProps} showHistory={true} />,
      { wrapper: Wrapper }
    );

    expect(getByText('test search 1')).toBeTruthy();
    expect(getByText('test search 2')).toBeTruthy();
  });

  it('handles history item selection', () => {
    const { getByText } = render(
      <SearchBar {...mockProps} showHistory={true} />,
      { wrapper: Wrapper }
    );

    const historyItem = getByText('test search 1');
    fireEvent.press(historyItem);

    expect(mockProps.onHistorySelect).toHaveBeenCalledWith('test search 1');
  });

  it('handles Enter key press', () => {
    const { getByPlaceholderText } = render(
      <SearchBar {...mockProps} inputText="test" />,
      { wrapper: Wrapper }
    );

    const input = getByPlaceholderText('Search in Japanese or English...');
    fireEvent.keyPress(input, { key: 'Enter', code: 13, charCode: 13 });

    expect(mockProps.onSearch).toHaveBeenCalledWith('test');
  });

  it('does not submit empty search', () => {
    const { getByRole } = render(
      <SearchBar {...mockProps} inputText="   " />,
      { wrapper: Wrapper }
    );

    const searchButton = getByRole('button', { name: 'Search' });
    fireEvent.press(searchButton);

    expect(mockProps.onSearch).not.toHaveBeenCalled();
  });
}); 