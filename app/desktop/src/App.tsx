import React from 'react';
import './styles/App.scss';

const App: React.FC = () => {
  return (
    <div className="app">
      <header className="app-header">
        <h1>Lang Desktop</h1>
      </header>
      <main className="app-content">
        <p>Welcome to Lang Desktop Application</p>
      </main>
    </div>
  );
};

export default App; 