# NutriMind System Architecture

## Overview
NutriMind is a Flutter-based mobile application for personalized meal planning and community engagement. The system leverages Firebase for backend services, Groq AI for meal generation, and follows a clean architecture pattern with Provider for state management.

## High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │    Firebase     │    │     Groq AI     │
│                 │    │                 │    │                 │
│ • UI Screens    │◄──►│ • Auth          │    │ • Meal          │
│ • Providers     │    │ • Firestore     │    │   Generation    │
│ • Services      │    │ • Storage       │    │                 │
│ • Models        │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   User Device   │
                    │                 │
                    │ • Mobile/Web    │
                    │ • Local Storage │
                    └─────────────────┘
```

## Component Breakdown

### 1. Frontend (Flutter)

#### UI Layer
- **Screens**: Organized in `lib/screens/` with subdirectories for auth, main, and onboarding
  - `auth_gate.dart`: Entry point for authentication
  - `login_screen.dart` & `register_screen.dart`: User authentication
  - `main_shell.dart`: Bottom navigation container
  - `home_screen.dart`: Main dashboard
  - `community_screen.dart`: Social features
  - `meal_plan_screen.dart`: Meal planning interface
  - `ai_meal_planner_screen.dart`: AI-powered meal creation with camera integration for food image analysis
  - `profile_screen.dart`: User profile management
  - Onboarding screens: `splash_screen.dart`, `biometrics_screen.dart`, `goal_screen.dart`

#### State Management Layer
- **Providers**: Located in `lib/providers/`
  - `auth_provider.dart`: Manages authentication state
  - `community_provider.dart`: Handles community data
  - `meal_provider.dart`: Manages meal planning data

#### Service Layer
- **Services**: Located in `lib/services/`
  - `auth_service.dart`: Firebase Auth integration
  - `firestore_service.dart`: Database operations
  - `groq_meal_narrative_service.dart`: AI meal generation
  - `meal_planner_service.dart`: Meal planning logic

#### Data Layer
- **Models**: Located in `lib/models/`
  - `user_model.dart`: User data structure
  - `meal_model.dart`: Meal data structure
  - `meal_planner_models.dart`: Meal planning data
  - `post_model.dart`: Community post structure

- **Data**: Located in `lib/data/`
  - `meal_planner_food_data.dart`: Food database with nutritional info
  - `firebase_options.dart`: Firebase configuration

#### Theme and Widgets
- **Theme**: `lib/theme/app_theme.dart` - App styling
- **Widgets**: `lib/widgets/` - Reusable UI components
  - `meal_planner/` - Meal planning specific widgets

### 2. Backend Services

#### Firebase
- **Authentication**: User login/signup with email/password and Google Sign-In
- **Firestore**: NoSQL database for user data, posts, and meal plans
- **Storage**: File uploads for profile images and post media

#### Groq AI
- **API Integration**: External AI service for generating meal descriptions and narratives
- **Vision Analysis**: Image recognition for food identification and calorie estimation
- **Prompt Engineering**: Pre-defined prompts in `meal_planner_prompts.dart`

### 3. Data Flow

#### Authentication Flow
```
User Input → Auth Screen → Auth Provider → Auth Service → Firebase Auth → Auth Provider → UI Update
```

#### Meal Planning Flow
```
User Selection → Meal Provider → Meal Service → Groq API → Meal Provider → AI Meal Planner Screen
```

#### Community Flow
```
User Action → Community Provider → Firestore Service → Firebase Firestore → Community Provider → Community Screen
```

### 4. Platform Support

#### Mobile Platforms
- **Android**: Native Android app via Flutter
- **iOS**: Native iOS app via Flutter

#### Desktop Platforms
- **Windows**: Desktop application
- **Web**: Browser-based application

#### Build Configuration
- `android/`: Android-specific configuration
- `ios/`: iOS-specific configuration (not shown in structure)
- `web/`: Web-specific configuration
- `windows/`: Windows-specific configuration

### 5. Dependencies and Libraries

#### Core Flutter
- `flutter`: Framework
- `cupertino_icons`: iOS-style icons

#### Firebase
- `firebase_core`: Core Firebase functionality
- `firebase_auth`: Authentication
- `cloud_firestore`: Database
- `firebase_storage`: File storage

#### State Management
- `provider`: State management solution

#### UI and Utilities
- `cached_network_image`: Image caching
- `image_picker`: Image selection
- `intl`: Internationalization
- `shared_preferences`: Local storage
- `uuid`: Unique ID generation
- `shimmer`: Loading animations
- `http`: HTTP requests

#### Development
- `flutter_test`: Testing framework
- `flutter_lints`: Code linting

### 6. Security Considerations

#### API Keys
- Firebase configuration in `firebase_options.dart`
- Groq API keys managed securely (not in code)

#### Data Privacy
- User data stored in Firebase with appropriate security rules
- Local data in shared preferences

#### Authentication
- Secure authentication flows
- Token management handled by Firebase

### 7. Performance Optimization

#### Image Handling
- Cached network images for efficient loading
- Firebase Storage for scalable media storage

#### State Management
- Provider pattern for efficient state updates
- Minimal rebuilds with proper key usage

#### Network Efficiency
- Firestore real-time listeners for live data
- Optimized queries and data structures

### 8. Deployment and CI/CD

#### Build Process
- Flutter build commands for different platforms
- Firebase configuration for production

#### Testing
- Unit tests in `test/` directory
- Integration tests for critical flows

#### Distribution
- App Store and Google Play deployment
- Web hosting for browser version

## Architecture Principles

1. **Separation of Concerns**: Clear division between UI, business logic, and data layers
2. **Provider Pattern**: Centralized state management for predictable data flow
3. **Service Layer**: Abstraction of external dependencies (Firebase, Groq)
4. **Model-Driven Development**: Strong typing with Dart models
5. **Platform Agnostic**: Single codebase for multiple platforms
6. **Scalable Backend**: Firebase for serverless scalability
7. **AI Integration**: External AI service for intelligent features

## Future Enhancements

- Image recognition integration for food identification
- Advanced analytics and personalization
- Offline-first architecture
- Real-time collaboration features
- Admin panel for content management