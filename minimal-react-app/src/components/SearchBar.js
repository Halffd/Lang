import React, { useState } from 'react';
import './SearchBar.css';

const SearchBar = ({ query, onSearch, searchHistory = [], showFurigana }) => {
  const [showHistoryDropdown, setShowHistoryDropdown] = useState(false);
  
  const handleSubmit = (e) => {
    e.preventDefault();
    onSearch(query);
    setShowHistoryDropdown(false);
  };
  
  const handleChange = (e) => {
    onSearch(e.target.value);
  };
  
  const handleHistoryItemClick = (item) => {
    onSearch(item);
    setShowHistoryDropdown(false);
  };
  
  const handleFocus = () => {
    if (searchHistory.length > 0) {
      setShowHistoryDropdown(true);
    }
  };
  
  return (
    <div className="search-bar-container">
      <form onSubmit={handleSubmit} className="search-form">
        <input
          type="text"
          value={query}
          onChange={handleChange}
          onFocus={handleFocus}
          placeholder="Search in Japanese..."
          className="search-input"
        />
        <button type="submit" className="search-button">Search</button>
      </form>
      
      {showHistoryDropdown && searchHistory.length > 0 && (
        <div className="history-dropdown">
          {searchHistory.map((item, index) => (
            <div 
              key={index} 
              className="history-item"
              onClick={() => handleHistoryItemClick(item)}
            >
              {item}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default SearchBar; 