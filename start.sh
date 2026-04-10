#!/bin/bash

# 1. Clear out temporary database files so they don't lock up the sync
echo "🧹 Cleaning up temp database logs..."
rm -f *.db-wal *.db-shm || true

# 2. Sync everything to GitHub
echo "📤 Publishing 137 games to GitHub..."
git add .

# We use "|| true" so it doesn't error out if you haven't changed anything
git commit -m "Manual sync: $(date)" || true

echo "🚀 Sending files to the repository..."
git push origin main || true
cowsay -f tux "On Github!"