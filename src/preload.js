const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('electronAPI', {
    // Notes operations
    getNotes: () => ipcRenderer.invoke('get-notes'),
    saveNote: (note) => ipcRenderer.invoke('save-note', note),
    deleteNote: (noteId) => ipcRenderer.invoke('delete-note', noteId),
    searchNotes: (query) => ipcRenderer.invoke('search-notes', query),

    // Menu events
    onMenuNewNote: (callback) => ipcRenderer.on('menu-new-note', callback),
    onMenuSaveNote: (callback) => ipcRenderer.on('menu-save-note', callback),

    // Notes data events
    onNotesLoaded: (callback) => ipcRenderer.on('notes-loaded', callback),

    // Remove listeners
    removeAllListeners: (channel) => ipcRenderer.removeAllListeners(channel)
});