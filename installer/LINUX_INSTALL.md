# Linux Installation and File Association Setup

## Installing GestureApp on Linux

After extracting the GestureApp Linux build, follow these steps to set up file associations for `.gsession` files:

### 1. Install MIME Type Definition

Copy the MIME type definition file to the appropriate location:

```bash
sudo cp gesture-app-session.xml /usr/share/mime/packages/
sudo update-mime-database /usr/share/mime
```

Or for user-only installation:

```bash
mkdir -p ~/.local/share/mime/packages/
cp gesture-app-session.xml ~/.local/share/mime/packages/
update-mime-database ~/.local/share/mime
```

### 2. Create Desktop Entry (Optional)

If you want `.gsession` files to open automatically with GestureApp, create a desktop entry:

```bash
cat > ~/.local/share/applications/gesture-app.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GestureApp
Comment=Gesture drawing practice application
Exec=/path/to/GestureApp %f
Icon=gesture-app
Terminal=false
Categories=Graphics;
MimeType=application/gesture-app-session;
EOF
```

Replace `/path/to/GestureApp` with the actual path to your GestureApp executable.

### 3. Update Desktop Database

```bash
update-desktop-database ~/.local/share/applications
```

### 4. Set Default Application (Optional)

To make GestureApp the default application for `.gsession` files:

```bash
xdg-mime default gesture-app.desktop application/gesture-app-session
```

## Verification

To verify the file association is working:

1. Right-click on a `.gsession` file
2. You should see GestureApp in the "Open With" menu
3. The file should display with the GestureApp icon

## Troubleshooting

If file associations are not working:

1. Make sure the MIME database is updated:
   ```bash
   update-mime-database ~/.local/share/mime
   ```

2. Clear the icon cache:
   ```bash
   gtk-update-icon-cache ~/.local/share/icons/hicolor/
   ```

3. Log out and log back in for changes to take full effect
