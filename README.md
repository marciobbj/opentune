<div align="center">
  <img src="assets/icons/app_icon.png" width="160" height="160" alt="OpenTune Logo">
  <h1>OpenTune</h1>
  <p>Advanced Audio Practice Tool for Musicians</p>
</div>

## Overview

OpenTune is a high-performance audio playback application specifically engineered for musicians, educators, and students who require precise control over their practice material. Built with Flutter and powered by the MediaKit engine, it provides a professional-grade environment for analyzing and mastering complex musical pieces.

## Core Features

### Tempo and Speed Manipulation
The application allows for real-time adjustments to playback speed ranging from 0.25x to 2.0x. This time-stretching algorithm maintains the original pitch of the audio, enabling users to practice intricate passages at slower speeds before moving to full tempo.

### Seamless Pitch Shifting
Users can shift the key of any audio track by plus or minus 12 semitones. This functionality is essential for practicing songs in different keys or adapting material to a specific vocal range without altering the playback speed.

### Intelligent Loop System
The loop selector provides multiple modes including Full Track, Section Loop, and Custom Range selection. The Custom Range mode allows for precise A-B looping with millisecond accuracy, ensuring focused practice on specific musical segments.

### Section Marker Management
OpenTune enables the creation of named markers throughout a track. Users can label important parts such as intros, choruses, and solos. These sections can be color-coded for visual organization and serve as instant navigation points.

### Advanced Library and Playlists
The built-in library manager allows for the organization of audio files into specific playlists. Users can create folder-like structures to group songs for upcoming performances, rehearsals, or specific technical studies.

### Dynamic Waveform Visualization
A real-time waveform display provides a detailed visual map of the audio track. This allows users to identify transients and structural changes in the music, facilitating easier navigation and more accurate marker placement.

## Technology Stack

- Framework: Flutter
- Performance Engine: Just Audio with MediaKit (libmpv)
- Metadata Handling: TagLib integration
- Local Storage: SQLite (sqflite)
- Platform Support: Linux (optimized for high-performance desktop audio)
