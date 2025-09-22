#!/bin/bash

# Zero Discipline Setup Script

set -e

echo "🎯 Zero Discipline setup completed!"
echo "================================"
echo

# Check if config.json exists
if [ ! -f "config.json" ]; then
    echo "📋 Creating config.json from example..."
    cp config.json.example config.json
    echo "✅ Configuration file created"
    echo
    echo "💡 You can edit config.json to customize:"
    echo "   - Which apps to monitor"
    echo "   - Timeout before closing apps"
    echo "   - Number of protected apps"
    echo
else
    echo "📋 Configuration file already exists"
    echo
fi

# Build the project
echo "🔨 Building the project..."
if make build > /dev/null 2>&1; then
    echo "✅ Build successful"
else
    echo "❌ Build failed. Please check the error messages above."
    exit 1
fi

echo
echo "🚀 Setup complete!"
echo
echo "You can now run:"
echo "  make run          # Run in development mode"
echo "  make run-release  # Run optimized version"
echo "  make app-bundle   # Create .app bundle"
echo
echo "The app will appear in your menu bar with a target icon 🎯"
echo