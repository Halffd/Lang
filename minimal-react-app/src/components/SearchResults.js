import React from 'react';
import './SearchResults.css';

const SearchResults = ({ results, onWordSelect, selectedResult, showFurigana = true }) => {
  if (!results || results.length === 0) {
    return (
      <div className="search-results-empty">
        <p>No results found. Enter a search term to begin.</p>
      </div>
    );
  }

  return (
    <div className="search-results">
      {results.map((result, index) => (
        <div 
          key={`${result.surface}-${index}`}
          className={`result-item ${selectedResult === result ? 'selected' : ''}`}
          onClick={() => onWordSelect(index)}
        >
          <div className="result-surface">{result.surface}</div>
          
          {showFurigana && result.reading && (
            <div className="result-reading">[{result.reading}]</div>
          )}
          
          {result.pos && (
            <div className="result-pos">({result.pos})</div>
          )}
          
          {result.definitions && result.definitions.length > 0 && (
            <div className="result-definitions">
              {result.definitions.map((def, defIndex) => (
                <div key={defIndex} className="result-definition">• {def}</div>
              ))}
            </div>
          )}
          
          {result.translations && result.translations.length > 0 && (
            <div className="result-translations">
              {result.translations.map((trans, transIndex) => (
                <div key={transIndex} className="result-translation">→ {trans}</div>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
};

export default SearchResults; 