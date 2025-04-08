import React from 'react';
import { render, screen } from '@testing-library/react';
import { NativeBaseProvider } from 'native-base';
import { ResultDetails } from './ResultDetails';
import { TokenizedWord } from '../../types';

const inset = {
  frame: { x: 0, y: 0, width: 0, height: 0 },
  insets: { top: 0, left: 0, right: 0, bottom: 0 },
};

const Wrapper = ({ children }: { children: React.ReactNode }) => (
  <NativeBaseProvider initialWindowMetrics={inset}>
    {children}
  </NativeBaseProvider>
);

describe('ResultDetails', () => {
  const mockResult: TokenizedWord = {
    surface: '食べる',
    reading: 'たべる',
    basic: '食べる',
    pos: '動詞',
    pos_detail: ['一段', '自立'],
    conjugation: '基本形',
    conjugation_type: '一段動詞',
    definitions: ['to eat', 'to consume'],
    translations: ['He eats rice', 'She is eating an apple'],
    frequency: 0.85,
  };

  it('renders basic word information correctly', () => {
    render(<ResultDetails result={mockResult} />, { wrapper: Wrapper });
    
    expect(screen.getByText('食べる')).toBeInTheDocument();
    expect(screen.getByText('たべる')).toBeInTheDocument();
    expect(screen.getByText('85%')).toBeInTheDocument();
  });

  it('renders grammar information correctly', () => {
    render(<ResultDetails result={mockResult} />, { wrapper: Wrapper });
    
    expect(screen.getByText('動詞')).toBeInTheDocument();
    expect(screen.getByText('一段')).toBeInTheDocument();
    expect(screen.getByText('自立')).toBeInTheDocument();
  });

  it('renders conjugation information correctly', () => {
    render(<ResultDetails result={mockResult} />, { wrapper: Wrapper });
    
    expect(screen.getByText('基本形')).toBeInTheDocument();
    expect(screen.getByText('一段動詞')).toBeInTheDocument();
  });

  it('renders definitions correctly', () => {
    render(<ResultDetails result={mockResult} />, { wrapper: Wrapper });
    
    expect(screen.getByText('1. to eat')).toBeInTheDocument();
    expect(screen.getByText('2. to consume')).toBeInTheDocument();
  });

  it('renders translations correctly', () => {
    render(<ResultDetails result={mockResult} />, { wrapper: Wrapper });
    
    expect(screen.getByText('He eats rice')).toBeInTheDocument();
    expect(screen.getByText('She is eating an apple')).toBeInTheDocument();
  });

  it('handles missing optional properties gracefully', () => {
    const minimalResult: TokenizedWord = {
      surface: '食べる',
      basic: '食べる',
      pos: '動詞',
    };

    render(<ResultDetails result={minimalResult} />, { wrapper: Wrapper });
    
    expect(screen.getByText('食べる')).toBeInTheDocument();
    expect(screen.getByText('動詞')).toBeInTheDocument();
    expect(screen.queryByText('たべる')).not.toBeInTheDocument();
    expect(screen.queryByText('%')).not.toBeInTheDocument();
  });

  it('applies correct styles to frequency badge', () => {
    render(<ResultDetails result={mockResult} />, { wrapper: Wrapper });
    
    const frequencyBadge = screen.getByText('85%');
    expect(frequencyBadge).toHaveClass('frequency');
  });

  it('applies correct styles to reading text', () => {
    render(<ResultDetails result={mockResult} />, { wrapper: Wrapper });
    
    const readingText = screen.getByText('たべる');
    expect(readingText).toHaveClass('reading');
  });

  it('applies correct styles to surface text', () => {
    render(<ResultDetails result={mockResult} />, { wrapper: Wrapper });
    
    const surfaceText = screen.getByText('食べる');
    expect(surfaceText).toHaveClass('surface');
  });
}); 