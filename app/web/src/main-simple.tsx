import React from 'react';
import { createRoot } from 'react-dom/client';
import './simple-styles.css';

// Simple App component
const App = () => {
  return (
    <div className="app-container">
      <header>
        <div className="header-content">
          <h1 className="app-title">Japanese Language Learning</h1>
        </div>
      </header>
      
      <main>
        <div className="search-container">
          <input 
            type="text" 
            className="search-input" 
            placeholder="Search for words in Japanese or English..."
          />
          <button className="search-button">Search</button>
        </div>
        
        <div className="results-container">
          <div className="result-card">
            <div className="word-japanese">猫</div>
            <div className="word-reading">ねこ (neko)</div>
            <div className="word-meaning">cat</div>
          </div>
          
          <div className="result-card">
            <div className="word-japanese">犬</div>
            <div className="word-reading">いぬ (inu)</div>
            <div className="word-meaning">dog</div>
          </div>
          
          <div className="result-card">
            <div className="word-japanese">鳥</div>
            <div className="word-reading">とり (tori)</div>
            <div className="word-meaning">bird</div>
          </div>
        </div>
      </main>
      
      <footer>
        <p>© 2023 Japanese Language Learning App</p>
      </footer>
    </div>
  );
};

// Render the app
const rootElement = document.getElementById('root');
if (rootElement) {
  const root = createRoot(rootElement);
  root.render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  );
} 