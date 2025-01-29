import { useState } from 'react';
import { FiSearch, FiSettings, FiClock, FiX, FiChevronRight } from 'react-icons/fi';

interface TokenizedWord {
  word: string;
  reading?: string;
  definitions: string[];
  translations?: string[];
}

interface HistoryItem {
  text: string;
  timestamp: number;
}

function App() {
  const [inputText, setInputText] = useState('');
  const [tokenizedWords, setTokenizedWords] = useState<TokenizedWord[]>([]);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [showHistory, setShowHistory] = useState(false);

  const handleAnalyze = async () => {
    if (!inputText.trim()) return;

    // Add to history
    const newHistoryItem = {
      text: inputText,
      timestamp: Date.now()
    };
    setHistory(prev => [newHistoryItem, ...prev.slice(0, 19)]); // Keep last 20 items

    // TODO: Implement actual tokenization through Tauri backend
    const mockTokenized: TokenizedWord[] = [
      {
        word: '私',
        reading: 'わたし',
        definitions: ['I', 'me', 'myself'],
        translations: ['I (personal pronoun)']
      }
    ];
    setTokenizedWords(mockTokenized);
  };

  const clearInput = () => {
    setInputText('');
    setTokenizedWords([]);
  };

  const loadFromHistory = (text: string) => {
    setInputText(text);
    setShowHistory(false);
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Native-like titlebar */}
      <div className="bg-gray-800 text-white px-4 py-2.5 flex items-center justify-between draggable">
        <div className="text-sm font-medium">Lang</div>
        <div className="flex items-center space-x-2">
          <button className="hover:bg-gray-700 p-1 rounded">
            <FiSettings className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Main content */}
      <main className="flex-1 container mx-auto px-4 py-6 max-w-4xl">
        {/* Search section */}
        <div className="relative">
          <div className="flex items-center gap-2 mb-4">
            <div className="relative flex-1">
              <div className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">
                <FiSearch className="w-5 h-5" />
              </div>
              <input
                type="text"
                value={inputText}
                onChange={(e) => setInputText(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleAnalyze()}
                className="w-full pl-10 pr-10 py-3 border border-gray-200 rounded-xl 
                          focus:ring-2 focus:ring-primary-500 focus:border-transparent
                          bg-white shadow-sm"
                placeholder="Enter text to analyze..."
              />
              {inputText && (
                <button 
                  onClick={clearInput}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 
                            hover:text-gray-600"
                >
                  <FiX className="w-5 h-5" />
                </button>
              )}
            </div>
            <button
              onClick={() => setShowHistory(prev => !prev)}
              className={`p-3 rounded-xl border ${
                showHistory 
                  ? 'bg-gray-100 border-gray-300' 
                  : 'border-gray-200 hover:bg-gray-50'
              }`}
            >
              <FiClock className="w-5 h-5 text-gray-600" />
            </button>
          </div>

          {/* History dropdown */}
          {showHistory && (
            <div className="absolute w-full bg-white rounded-xl shadow-lg border 
                          border-gray-200 mt-1 z-10 max-h-80 overflow-y-auto">
              {history.length === 0 ? (
                <div className="p-4 text-gray-500 text-center">No history yet</div>
              ) : (
                history.map((item, index) => (
                  <button
                    key={item.timestamp}
                    onClick={() => loadFromHistory(item.text)}
                    className="w-full px-4 py-3 flex items-center justify-between 
                              hover:bg-gray-50 border-b border-gray-100 last:border-0"
                  >
                    <div className="flex items-center">
                      <FiClock className="w-4 h-4 text-gray-400 mr-3" />
                      <span className="text-gray-700">{item.text}</span>
                    </div>
                    <FiChevronRight className="w-4 h-4 text-gray-400" />
                  </button>
                ))
              )}
            </div>
          )}
        </div>

        {/* Results section */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-6">
          {tokenizedWords.map((word, index) => (
            <div 
              key={index}
              className="bg-white p-4 rounded-xl shadow-sm hover:shadow-md 
                        transition-shadow border border-gray-100"
            >
              <div className="mb-3 pb-2 border-b border-gray-100">
                <span className="text-xl font-medium">{word.word}</span>
                {word.reading && (
                  <span className="ml-2 text-sm text-gray-600">({word.reading})</span>
                )}
              </div>
              <div className="space-y-1.5">
                {word.definitions.map((def, idx) => (
                  <div key={idx} className="text-sm text-gray-700 leading-relaxed">
                    {idx + 1}. {def}
                  </div>
                ))}
                {word.translations && (
                  <div className="mt-3 pt-2 border-t border-gray-100">
                    {word.translations.map((trans, idx) => (
                      <div key={idx} className="text-sm text-gray-500 italic">
                        {trans}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}

export default App;
