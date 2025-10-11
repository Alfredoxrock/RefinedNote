const { app, BrowserWindow, Menu, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs').promises;

// Keep a global reference of the window object
let mainWindow;

// Store notes data
let notesData = [];
let currentNoteId = null;

// Notes storage path
const notesPath = path.join(app.getPath('userData'), 'notes.json');

function createWindow() {
    // Create the browser window
    mainWindow = new BrowserWindow({
        width: 1200,
        height: 800,
        minWidth: 800,
        minHeight: 600,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js')
        },
        icon: path.join(__dirname, '..', 'assets', 'icon.png'),
        show: false
    });

    // Load the app
    mainWindow.loadFile(path.join(__dirname, 'index.html'));

    // Show window when ready to prevent visual flash
    mainWindow.once('ready-to-show', () => {
        mainWindow.show();
    });

    // Handle window closed
    mainWindow.on('closed', () => {
        mainWindow = null;
    });

    // Create application menu
    createMenu();

    // Load notes data
    loadNotesData();
}

function createMenu() {
    const template = [
        {
            label: 'File',
            submenu: [
                {
                    label: 'New Note',
                    accelerator: 'CmdOrCtrl+N',
                    click: () => {
                        mainWindow.webContents.send('menu-new-note');
                    }
                },
                {
                    label: 'Save Note',
                    accelerator: 'CmdOrCtrl+S',
                    click: () => {
                        mainWindow.webContents.send('menu-save-note');
                    }
                },
                { type: 'separator' },
                {
                    label: 'Exit',
                    accelerator: process.platform === 'darwin' ? 'Cmd+Q' : 'Ctrl+Q',
                    click: () => {
                        app.quit();
                    }
                }
            ]
        },
        {
            label: 'Edit',
            submenu: [
                { role: 'undo' },
                { role: 'redo' },
                { type: 'separator' },
                { role: 'cut' },
                { role: 'copy' },
                { role: 'paste' },
                { role: 'selectall' }
            ]
        },
        {
            label: 'View',
            submenu: [
                { role: 'reload' },
                { role: 'forceReload' },
                { role: 'toggleDevTools' },
                { type: 'separator' },
                { role: 'resetZoom' },
                { role: 'zoomIn' },
                { role: 'zoomOut' },
                { type: 'separator' },
                { role: 'togglefullscreen' }
            ]
        }
    ];

    const menu = Menu.buildFromTemplate(template);
    Menu.setApplicationMenu(menu);
}

async function loadNotesData() {
    try {
        const data = await fs.readFile(notesPath, 'utf8');
        notesData = JSON.parse(data);
    } catch (error) {
        // File doesn't exist or is invalid, start with empty array
        notesData = [];
    }

    // Send notes to renderer
    if (mainWindow) {
        mainWindow.webContents.send('notes-loaded', notesData);
    }
}

async function saveNotesData() {
    try {
        await fs.writeFile(notesPath, JSON.stringify(notesData, null, 2));
    } catch (error) {
        console.error('Error saving notes:', error);
    }
}

// App event handlers
app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
    }
});

// IPC handlers
ipcMain.handle('get-notes', () => {
    return notesData;
});

ipcMain.handle('save-note', async (event, note) => {
    if (note.id) {
        // Update existing note
        const index = notesData.findIndex(n => n.id === note.id);
        if (index !== -1) {
            notesData[index] = { ...note, updatedAt: new Date().toISOString() };
        }
    } else {
        // Create new note
        const newNote = {
            ...note,
            id: Date.now().toString(),
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };
        notesData.unshift(newNote);
    }

    await saveNotesData();
    return notesData;
});

ipcMain.handle('delete-note', async (event, noteId) => {
    notesData = notesData.filter(note => note.id !== noteId);
    await saveNotesData();
    return notesData;
});

ipcMain.handle('search-notes', (event, query) => {
    if (!query) return notesData;

    const searchTerm = query.toLowerCase();
    return notesData.filter(note =>
        note.title.toLowerCase().includes(searchTerm) ||
        note.content.toLowerCase().includes(searchTerm)
    );
});