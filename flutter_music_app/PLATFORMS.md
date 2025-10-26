# Platform Support

This Flutter app supports **Android** and **Linux** platforms.

## Android

### Requirements
- Android SDK 21 (Lollipop) or higher
- Android Studio or Flutter SDK

### Permissions
The app requires the following permissions:
- `INTERNET` - Network access to communicate with the server
- `READ_EXTERNAL_STORAGE` - Read audio files (Android 12 and below)
- `WRITE_EXTERNAL_STORAGE` - Save downloaded songs (Android 12 and below)
- `READ_MEDIA_AUDIO` - Access audio files (Android 13+)

### Building for Android

**Debug build (for testing):**
```bash
flutter run
```

**Release APK:**
```bash
flutter build apk --release
```
The APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`

**Install on device:**
```bash
flutter install
# or
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Package Name
`com.musicserver.app`

### App Name
Music Server

## Linux

### Requirements
- Flutter SDK with Linux desktop support enabled
- GTK+ 3.0 development libraries
- CMake 3.13 or higher
- Clang

### Install Linux Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

**Fedora:**
```bash
sudo dnf install clang cmake ninja-build gtk3-devel
```

**Arch Linux:**
```bash
sudo pacman -S clang cmake ninja gtk3
```

### Building for Linux

**Debug build:**
```bash
flutter run -d linux
```

**Release build:**
```bash
flutter build linux --release
```
The executable will be located at: `build/linux/x64/release/bundle/music_server`

### Running the Linux App

After building, run:
```bash
./build/linux/x64/release/bundle/music_server
```

Or install it to your system:
```bash
# Copy the bundle to /opt
sudo cp -r build/linux/x64/release/bundle /opt/music-server

# Create a desktop entry
cat > ~/.local/share/applications/music-server.desktop << EOF
[Desktop Entry]
Name=Music Server
Comment=Personal music streaming client
Exec=/opt/music-server/music_server
Icon=audio-player
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Player;
EOF

# Update desktop database
update-desktop-database ~/.local/share/applications/
```

### Application ID
`com.musicserver.app`

### Binary Name
`music_server`

## Troubleshooting

### Android

**Issue: App crashes on download**
- Ensure storage permissions are granted
- Check Android version (13+ requires different permissions)

**Issue: Cannot connect to server**
- Verify server IP and port
- Ensure INTERNET permission is granted
- Check firewall settings on server

### Linux

**Issue: Missing GTK libraries**
```bash
sudo apt-get install libgtk-3-0
```

**Issue: Cannot find Flutter**
```bash
flutter doctor
flutter config --enable-linux-desktop
```

**Issue: Build fails with CMake errors**
- Ensure CMake 3.13+ is installed
- Update build tools: `sudo apt-get install build-essential`

## Testing

### Android Emulator
```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator_id>

# Run app
flutter run
```

### Linux
```bash
flutter run -d linux
```

## File Locations

### Android
- Downloads: `/storage/emulated/0/Android/data/com.musicserver.app/files/Music/`
- Shared preferences: `/data/data/com.musicserver.app/shared_prefs/`

### Linux
- Downloads: `~/.local/share/music_server/Music/`
- Config: `~/.local/share/music_server/`
