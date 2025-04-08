import React, { createContext, useContext } from 'react';
import { useTokenizer, TokenizerState } from '../hooks/useTokenizer';

const TokenizerContext = createContext<TokenizerState | null>(null);

export function TokenizerProvider({ children }: { children: React.ReactNode }) {
  const tokenizerState = useTokenizer();

  return (
    <TokenizerContext.Provider value={tokenizerState}>
      {children}
    </TokenizerContext.Provider>
  );
}

export function useTokenizerContext(): TokenizerState {
  const context = useContext(TokenizerContext);
  if (!context) {
    throw new Error('useTokenizerContext must be used within a TokenizerProvider');
  }
  return context;
} 