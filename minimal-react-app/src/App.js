import React, { useState } from 'react';
import './App.css';
import SearchBar from './components/SearchBar';
import SearchResults from './components/SearchResults';
import Translator from './components/Translator';
import SettingsModal from './components/SettingsModal';

function App() {
  const [activeTab, setActiveTab] = useState('dictionary');
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [selectedResult, setSelectedResult] = useState(null);
  const [searchHistory, setSearchHistory] = useState([]);
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [settings, setSettings] = useState({
    showFurigana: true
  });

  const handleSearch = (searchQuery) => {
    setQuery(searchQuery);
    if (!searchQuery.trim()) {
      setResults([]);
      return;
    }

    // Add to history
    if (!searchHistory.includes(searchQuery)) {
      setSearchHistory([searchQuery, ...searchHistory].slice(0, 10));
    }

    // Mock search results
    const mockResults = [
      {
        surface: searchQuery,
        reading: `${searchQuery} reading`,
        pos: 'Noun',
        definitions: ['Definition 1', 'Definition 2'],
        translations: ['Translation 1', 'Translation 2']
      },
      {
        surface: `${searchQuery}2`,
        reading: `${searchQuery}2 reading`,
        pos: 'Verb',
        definitions: ['Another definition'],
        translations: ['Another translation']
      }
    ];

    setResults(mockResults);
  };

  const handleTranslate = (text, sourceLang, targetLang, mode) => {
    // Mock translation
    switch (mode) {
      case 'per-word':
        return text.split(' ').map(word => `[${word}-translated]`).join(' ');
      case 'dictionary':
        return `Dictionary translation of: ${text}`;
      case 'scraping':
        return `Web scraping translation of: ${text}`;
      default:
        return `Translated: ${text}`;
    }
  };

  const handleWordSelect = (index) => {
    setSelectedResult(results[index]);
  };

  const updateSetting = (key, value) => {
    setSettings(prev => ({
      ...prev,
      [key]: value
    }));
  };

  return (
    <div className="app-container">
      <header>
        <h1>Lang - Japanese Dictionary</h1>
        
        <div className="tabs">
          <div 
            className={`tab ${activeTab === 'dictionary' ? 'active' : ''}`}
            onClick={() => setActiveTab('dictionary')}
          >
            Dictionary Search
          </div>
          <div 
            className={`tab ${activeTab === 'translator' ? 'active' : ''}`}
            onClick={() => setActiveTab('translator')}
          >
            Translator
          </div>
          
          <button 
            className="settings-button"
            onClick={() => setShowSettingsModal(true)}
          >
            ⚙️ Settings
          </button>
        </div>
      </header>
      
      <main>
        {activeTab === 'dictionary' ? (
          <div className="dictionary-container">
            <SearchBar 
              query={query} 
              onSearch={handleSearch} 
              searchHistory={searchHistory}
              showFurigana={settings.showFurigana}
            />
            
            <SearchResults 
              results={results}
              onWordSelect={handleWordSelect}
              selectedResult={selectedResult}
              showFurigana={settings.showFurigana}
            />
          </div>
        ) : (
          <Translator onTranslate={handleTranslate} />
        )}
      </main>
      
      {showSettingsModal && (
        <SettingsModal 
          settings={settings}
          onClose={() => setShowSettingsModal(false)}
          onUpdateSetting={updateSetting}
        />
      )}
    </div>
  );
}

export default App; 