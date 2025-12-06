import React from 'react';
import './SettingsModal.css';

const SettingsModal = ({ settings, onClose, onUpdateSetting }) => {
  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };
  
  return (
    <div className="modal-backdrop" onClick={handleBackdropClick}>
      <div className="modal-content">
        <div className="modal-header">
          <h2>Settings</h2>
          <span className="modal-close" onClick={onClose}>×</span>
        </div>
        
        <div className="settings-list">
          <div className="setting-item">
            <span>Show Furigana</span>
            <label className="switch">
              <input 
                type="checkbox" 
                checked={settings.showFurigana} 
                onChange={(e) => onUpdateSetting('showFurigana', e.target.checked)}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SettingsModal; 