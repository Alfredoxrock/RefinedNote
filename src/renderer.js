// Application state
let notes = [];
let currentNote = null;
let isSearching = false;

// DOM elements
const newNoteBtn = document.getElementById('new-note-btn');
const searchInput = document.getElementById('search-input');
const clearSearchBtn = document.getElementById('clear-search');
const notesList = document.getElementById('notes-list');
const emptyState = document.getElementById('empty-state');
const noteTitle = document.getElementById('note-title');
const noteContent = document.getElementById('note-content');
const saveNoteBtn = document.getElementById('save-note-btn');
const deleteNoteBtn = document.getElementById('delete-note-btn');
const statusText = document.getElementById('status-text');
const wordCount = document.getElementById('word-count');
const deleteModal = document.getElementById('delete-modal');
const cancelDeleteBtn = document.getElementById('cancel-delete');
const confirmDeleteBtn = document.getElementById('confirm-delete');

// Initialize app
document.addEventListener('DOMContentLoaded', async () => {
    await loadNotes();
    setupEventListeners();
    updateWordCount();
    initializeTheme();
});

// Setup event listeners
function setupEventListeners() {
    // New note button
    newNoteBtn.addEventListener('click', createNewNote);

    // Search functionality
    searchInput.addEventListener('input', handleSearch);
    clearSearchBtn.addEventListener('click', clearSearch);

    // Note editing
    noteTitle.addEventListener('input', handleNoteChange);
    noteContent.addEventListener('input', handleNoteChange);

    // Save and delete buttons
    saveNoteBtn.addEventListener('click', saveCurrentNote);
    deleteNoteBtn.addEventListener('click', showDeleteModal);

    // Modal handlers
    cancelDeleteBtn.addEventListener('click', hideDeleteModal);
    confirmDeleteBtn.addEventListener('click', deleteCurrentNote);
    deleteModal.addEventListener('click', (e) => {
        if (e.target === deleteModal) hideDeleteModal();
    });

    // Keyboard shortcuts
    document.addEventListener('keydown', handleKeyboard);

    // Menu events from main process
    window.electronAPI.onMenuNewNote(() => createNewNote());
    window.electronAPI.onMenuSaveNote(() => saveCurrentNote());

    // Theme toggle
    const themeToggleBtn = document.getElementById('theme-toggle-btn');
    const themeIcon = document.getElementById('theme-icon');
    if (themeToggleBtn) {
        themeToggleBtn.addEventListener('click', () => {
            toggleTheme();
            // update icon
            const isDark = document.documentElement.classList.contains('theme-dark');
            themeIcon.classList.toggle('fa-sun', isDark);
            themeIcon.classList.toggle('fa-moon', !isDark);
        });
    }

    // Update word count on content change
    noteContent.addEventListener('input', updateWordCount);
}

// Theme support
function initializeTheme() {
    const saved = localStorage.getItem('notes-theme');
    if (saved) {
        if (saved === 'dark') document.documentElement.classList.add('theme-dark');
    } else {
        // Respect OS preference on first run
        const prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
        if (prefersDark) document.documentElement.classList.add('theme-dark');
    }

    // Set initial icon
    const themeIcon = document.getElementById('theme-icon');
    if (themeIcon) {
        const isDark = document.documentElement.classList.contains('theme-dark');
        themeIcon.classList.toggle('fa-sun', isDark);
        themeIcon.classList.toggle('fa-moon', !isDark);
    }
}

function toggleTheme() {
    const isDark = document.documentElement.classList.toggle('theme-dark');
    localStorage.setItem('notes-theme', isDark ? 'dark' : 'light');
}

// Load notes from storage
async function loadNotes() {
    try {
        notes = await window.electronAPI.getNotes();
        renderNotesList();
        updateStatus('Notes loaded');
    } catch (error) {
        console.error('Error loading notes:', error);
        updateStatus('Error loading notes', true);
    }
}

// Render notes list in sidebar
function renderNotesList() {
    const notesToShow = isSearching ?
        notes.filter(note =>
            note.title.toLowerCase().includes(searchInput.value.toLowerCase()) ||
            note.content.toLowerCase().includes(searchInput.value.toLowerCase())
        ) : notes;

    if (notesToShow.length === 0) {
        notesList.innerHTML = '';
        emptyState.style.display = 'block';
        return;
    }

    emptyState.style.display = 'none';

    notesList.innerHTML = notesToShow.map(note => `
        <div class="note-item ${currentNote && currentNote.id === note.id ? 'active' : ''}" 
             data-note-id="${note.id}">
            <div class="note-item-title">${note.title || 'Untitled Note'}</div>
            <div class="note-item-preview">${note.content || 'No content'}</div>
            <div class="note-item-date">${formatDate(note.updatedAt || note.createdAt)}</div>
        </div>
    `).join('');

    // Add click listeners to note items
    document.querySelectorAll('.note-item').forEach(item => {
        item.addEventListener('click', () => {
            const noteId = item.dataset.noteId;
            const note = notes.find(n => n.id === noteId);
            if (note) {
                loadNote(note);
            }
        });
    });
}

// Create new note
function createNewNote() {
    currentNote = {
        id: null,
        title: '',
        content: '',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
    };

    noteTitle.value = '';
    noteContent.value = '';
    noteTitle.focus();

    deleteNoteBtn.disabled = true;
    updateStatus('New note created');
    updateWordCount();
    renderNotesList(); // Remove active state from other notes
}

// Load note into editor
function loadNote(note) {
    currentNote = { ...note };
    noteTitle.value = note.title || '';
    noteContent.value = note.content || '';

    deleteNoteBtn.disabled = false;
    updateStatus('Note loaded');
    updateWordCount();
    renderNotesList(); // Update active state
}

// Handle note content changes
function handleNoteChange() {
    if (!currentNote) return;

    currentNote.title = noteTitle.value;
    currentNote.content = noteContent.value;
    currentNote.updatedAt = new Date().toISOString();

    updateStatus('Modified', false, true);
}

// Save current note
async function saveCurrentNote() {
    if (!currentNote) {
        createNewNote();
        return;
    }

    if (!currentNote.title.trim() && !currentNote.content.trim()) {
        updateStatus('Cannot save empty note', true);
        return;
    }

    try {
        currentNote.title = noteTitle.value || 'Untitled Note';
        currentNote.content = noteContent.value;

        const hadId = Boolean(currentNote.id);
        notes = await window.electronAPI.saveNote(currentNote);

        // If we created a new note (no id before), it's added to the start of the notes array by the main process
        let savedNote = null;
        if (hadId) {
            savedNote = notes.find(n => n.id === currentNote.id) || null;
        } else {
            // assume newest at front
            savedNote = notes.length > 0 ? notes[0] : null;
        }

        // Refresh the sidebar
        renderNotesList();

        // Clear editor and prepare a new note
        createNewNote();

        // Logically we keep saved note in the list; user can click it to load
        updateStatus('Note saved');
    } catch (error) {
        console.error('Error saving note:', error);
        updateStatus('Error saving note', true);
    }
}

// Show delete confirmation modal
function showDeleteModal() {
    if (!currentNote || !currentNote.id) return;
    deleteModal.classList.add('show');
}

// Hide delete confirmation modal
function hideDeleteModal() {
    deleteModal.classList.remove('show');
}

// Delete current note
async function deleteCurrentNote() {
    if (!currentNote || !currentNote.id) return;

    try {
        notes = await window.electronAPI.deleteNote(currentNote.id);

        hideDeleteModal();

        // Clear editor and load first note if available
        if (notes.length > 0) {
            loadNote(notes[0]);
        } else {
            createNewNote();
        }

        renderNotesList();
        updateStatus('Note deleted');
    } catch (error) {
        console.error('Error deleting note:', error);
        updateStatus('Error deleting note', true);
        hideDeleteModal();
    }
}

// Handle search input
function handleSearch() {
    const query = searchInput.value.trim();
    isSearching = query.length > 0;

    clearSearchBtn.classList.toggle('show', isSearching);
    renderNotesList();

    if (isSearching) {
        updateStatus(`Found ${notesList.children.length} results`);
    } else {
        updateStatus('Ready');
    }
}

// Clear search
function clearSearch() {
    searchInput.value = '';
    isSearching = false;
    clearSearchBtn.classList.remove('show');
    renderNotesList();
    updateStatus('Ready');
    searchInput.focus();
}

// Handle keyboard shortcuts
function handleKeyboard(e) {
    if (e.ctrlKey || e.metaKey) {
        switch (e.key) {
            case 'n':
                e.preventDefault();
                createNewNote();
                break;
            case 's':
                e.preventDefault();
                saveCurrentNote();
                break;
            case 'f':
                e.preventDefault();
                searchInput.focus();
                break;
        }
    }

    // Escape key to clear search or close modal
    if (e.key === 'Escape') {
        if (deleteModal.classList.contains('show')) {
            hideDeleteModal();
        } else if (isSearching) {
            clearSearch();
        }
    }
}

// Update status bar
function updateStatus(message, isError = false, isModified = false) {
    statusText.textContent = message;
    statusText.style.color = isError ? '#f56565' : (isModified ? '#ed8936' : '#718096');

    if (!isError && !isModified) {
        setTimeout(() => {
            if (statusText.textContent === message) {
                statusText.textContent = 'Ready';
                statusText.style.color = '#718096';
            }
        }, 3000);
    }
}

// Update word count
function updateWordCount() {
    const content = noteContent.value.trim();
    const words = content ? content.split(/\s+/).length : 0;
    wordCount.textContent = `${words} words`;
}

// Format date for display
function formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diffTime = Math.abs(now - date);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays === 1) {
        return 'Today';
    } else if (diffDays === 2) {
        return 'Yesterday';
    } else if (diffDays <= 7) {
        return `${diffDays - 1} days ago`;
    } else {
        return date.toLocaleDateString();
    }
}

// Initialize with first note if available
window.electronAPI.onNotesLoaded((event, loadedNotes) => {
    notes = loadedNotes;
    renderNotesList();

    if (notes.length > 0) {
        loadNote(notes[0]);
    } else {
        createNewNote();
    }
});