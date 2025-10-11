# Notes Desktop App

A modern, elegant desktop note-taking application built with Electron. Features a clean interface with sidebar navigation, real-time search, and seamless note management.

## Features

- **Modern UI**: Clean, intuitive interface with a beautiful gradient sidebar
- **Note Management**: Create, edit, save, and delete notes with ease
- **Real-time Search**: Instantly search through all your notes by title or content
- **Keyboard Shortcuts**: 
  - `Ctrl+N` (or `Cmd+N`) - Create new note
  - `Ctrl+S` (or `Cmd+S`) - Save current note
  - `Ctrl+F` (or `Cmd+F`) - Focus search
  - `Escape` - Clear search or close modals
- **Auto-save**: Notes are automatically marked as modified when you type
- **Word Count**: Real-time word count display in the status bar
- **Responsive Design**: Optimized for various screen sizes
- **Data Persistence**: Notes are saved locally and persist between sessions

## Screenshots

The application features:
- **Sidebar**: Notes list with search functionality and creation button
- **Main Editor**: Title input and content textarea with formatting
- **Status Bar**: Word count and application status
- **Modern Design**: Uses Inter font and beautiful color gradients

## Installation

### Prerequisites
- Node.js (version 14 or higher)
- npm or yarn

### Setup
1. Clone or download this repository
2. Navigate to the project directory
3. Install dependencies:
   ```bash
   npm install
   ```

## Usage

### Development
To run the application in development mode:
```bash
npm run dev
```

### Production
To start the application:
```bash
npm start
```

### Building Distributables
To build the application for distribution:
```bash
npm run build
```

This will create distributables for your current platform in the `dist` folder.

## Project Structure

```
notes-desktop-app/
├── src/
│   ├── main.js          # Main Electron process
│   ├── preload.js       # Preload script for security
│   ├── index.html       # Application UI
│   ├── styles.css       # Application styles
│   └── renderer.js      # Renderer process logic
├── assets/
│   └── AppLogo.png      # Application icon (placeholder)
├── package.json         # Project configuration
└── README.md           # This file
```

## Technical Details

### Architecture
- **Main Process**: Handles application lifecycle, window management, and file operations
- **Renderer Process**: Manages the UI and user interactions
- **Preload Script**: Provides secure communication between main and renderer processes

### Data Storage
- Notes are stored in JSON format in the user's application data directory
- Each note contains: ID, title, content, creation date, and last modified date

### Security
- Context isolation enabled
- Node integration disabled in renderer process
- Secure IPC communication through preload script

## Development Guidelines

### Code Style
- Use modern JavaScript (ES6+) features
- Follow Electron security best practices
- Maintain clean separation between main and renderer processes
- Use CSS Grid/Flexbox for responsive layout
- Implement proper error handling and user feedback

### Contributing
1. Follow the existing code style and structure
2. Test changes thoroughly
3. Update documentation as needed
4. Ensure security best practices are maintained

## License

MIT License - feel free to use this project as a starting point for your own note-taking application.

## Future Enhancements

Potential features to add:
- Rich text formatting (bold, italic, lists)
- Note categories and tags
- Export functionality (PDF, Markdown)
- Note sharing capabilities
- Dark mode theme
- Markdown preview
- File attachments
- Sync across devices