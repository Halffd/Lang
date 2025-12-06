const { app, BrowserWindow, dialog } = require('electron');
const path = require('path');
const isDev = require('electron-is-dev');

// Disable hardware acceleration to prevent some rendering issues
app.disableHardwareAcceleration();

// Handle Electron crash events
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  dialog.showErrorBox('Application Error', `An error occurred: ${error.message}`);
});

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1024,
    height: 768,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      webSecurity: true
    }
  });

  // Allow loading from different URLs based on environment variables
  let startUrl;
  
  if (process.env.ELECTRON_START_URL) {
    // Use custom URL if specified (useful for create-react-app)
    startUrl = process.env.ELECTRON_START_URL;
  } else if (isDev) {
    // Default development URL (Expo)
    startUrl = 'http://localhost:19006';
  } else {
    // Production build
    startUrl = `file://${path.join(__dirname, 'web-build/index.html')}`;
  }

  console.log('Loading from URL:', startUrl);
  
  mainWindow.loadURL(startUrl);

  // Open the DevTools in development mode
  if (isDev) {
    mainWindow.webContents.openDevTools();
  }

  mainWindow.on('closed', () => (mainWindow = null));
}

app.whenReady().then(() => {
  createWindow();
  
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
}); 