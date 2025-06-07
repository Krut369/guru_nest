# Guru Nest

A modern Flutter-based learning platform with Supabase backend integration.

## Overview

Guru Nest is a comprehensive learning platform built with Flutter that provides an interactive and engaging learning experience. The application uses Supabase as its backend service for authentication, database, and storage.

## Features

- Modern and responsive UI design
- Cross-platform support (iOS, Android, Web)
- Secure authentication system
- Real-time data synchronization
- Interactive learning materials
- Progress tracking and analytics
- File upload and management
- Customizable user profiles
- Real-time chat functionality

## Tech Stack

- **Frontend Framework**: Flutter
- **State Management**: Flutter Riverpod
- **Backend**: Supabase
- **Routing**: Go Router
- **Code Generation**: Freezed, JSON Serializable
- **UI Components**: Material Design
- **Charts**: FL Chart
- **File Handling**: File Picker, Image Picker
- **Local Storage**: Shared Preferences

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Supabase account and project
- IDE (VS Code, Android Studio, or IntelliJ IDEA)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/guru_nest.git
   ```

2. Navigate to the project directory:
   ```bash
   cd guru_nest
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Configure Supabase:
   - The project uses a singleton Supabase client for connection
   - Supabase configuration is handled in `lib/core/supabase_client.dart`
   - The client is initialized in the `main.dart` file

5. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── core/           # Core functionality and configurations
│   ├── router/     # Routing configuration
│   ├── theme/      # App theme and styling
│   ├── routes.dart # Route definitions
│   ├── supabase_client.dart # Supabase configuration and client
│   └── constants.dart
├── features/       # Feature-based modules
│   └── chat/       # Chat functionality
├── models/         # Data models
├── pages/          # Page components
├── providers/      # State management providers
├── screens/        # Screen components
├── services/       # Service layer
├── utils/          # Utility functions
├── views/          # View components
├── widgets/        # Reusable widgets
└── main.dart       # Application entry point
```

### Directory Structure Details

- **core/**: Contains core application configurations, routing, and theming
  - **supabase_client.dart**: Handles Supabase connection and configuration
- **features/**: Feature-based modules with their own models, views, and controllers
- **models/**: Data models and entities
- **pages/**: Page-level components
- **providers/**: State management using Riverpod
- **screens/**: Screen components and layouts
- **services/**: API services and business logic
- **utils/**: Helper functions and utilities
- **views/**: View components and UI elements
- **widgets/**: Reusable UI components

## Development

- The project uses Flutter Riverpod for state management
- Code generation is handled by build_runner
- Device Preview is enabled in debug mode for responsive testing
- Follow the feature-first architecture pattern for new features
- Supabase client is implemented as a singleton for consistent connection management

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Supabase for the backend services
- All contributors who have helped shape this project
