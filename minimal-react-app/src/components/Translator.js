import React, { useState } from 'react';
import './Translator.css';

const Translator = ({ onTranslate }) => {
  const [text, setText] = useState('');
  const [sourceLang, setSourceLang] = useState('ja');
  const [targetLang, setTargetLang] = useState('en');
  const [mode, setMode] = useState('per-word');
  const [result, setResult] = useState('');
  
  const handleTranslate = () => {
    if (!text.trim()) {
      setResult('Please enter text to translate');
      return;
    }
    
    const translatedText = onTranslate(text, sourceLang, targetLang, mode);
    setResult(translatedText);
  };
  
  return (
    <div className="translator-container">
      <textarea
        className="translator-input"
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Enter text to translate..."
      />
      
      <div className="translate-options">
        <div className="translate-option">
          <label htmlFor="source-lang">From:</label>
          <select 
            id="source-lang" 
            value={sourceLang} 
            onChange={(e) => setSourceLang(e.target.value)}
          >
            <option value="ja">Japanese</option>
            <option value="en">English</option>
          </select>
        </div>
        
        <div className="translate-option">
          <label htmlFor="target-lang">To:</label>
          <select 
            id="target-lang" 
            value={targetLang} 
            onChange={(e) => setTargetLang(e.target.value)}
          >
            <option value="en">English</option>
            <option value="ja">Japanese</option>
          </select>
        </div>
        
        <div className="translate-option">
          <label htmlFor="translate-mode">Mode:</label>
          <select 
            id="translate-mode" 
            value={mode} 
            onChange={(e) => setMode(e.target.value)}
          >
            <option value="per-word">Per Word</option>
            <option value="dictionary">Dictionary</option>
            <option value="scraping">Web Scraping</option>
          </select>
        </div>
        
        <button onClick={handleTranslate} className="translate-button">
          Translate
        </button>
      </div>
      
      <div className="translate-result">
        {result || 'Translation will appear here'}
      </div>
    </div>
  );
};

export default Translator; 