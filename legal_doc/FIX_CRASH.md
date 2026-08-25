# Fixing SIGTERM Crash

## Problem
The app crashes with `Thread 1: signal SIGTERM` when launching. This is typically caused by a Core Data schema mismatch after adding the new `AppLog` entity.

## Solution

### Option 1: Delete App and Reinstall (Recommended for Development)

1. **On Simulator:**
   - Long press the app icon
   - Tap the "X" to delete
   - Rebuild and run from Xcode

2. **On Physical Device:**
   - Long press the app icon
   - Tap "Remove App" → "Delete App"
   - Rebuild and run from Xcode

This will create a fresh Core Data store with the new schema including the `AppLog` entity.

### Option 2: Reset Simulator (If Option 1 doesn't work)

1. In Xcode: **Device** → **Erase All Content and Settings**
2. Rebuild and run the app

### Option 3: Clean Build Folder

1. In Xcode: **Product** → **Clean Build Folder** (Shift+Cmd+K)
2. Delete Derived Data:
   - Xcode → Preferences → Locations
   - Click arrow next to Derived Data path
   - Delete the folder for your project
3. Rebuild and run

## Why This Happens

When you add a new entity to an existing Core Data model that's already been used, Core Data needs to migrate the database schema. For development, the easiest solution is to delete the app and start fresh.

## Prevention

For production apps, you would need to:
1. Create a new Core Data model version
2. Implement a migration policy
3. Test the migration thoroughly

For now, deleting and reinstalling is the quickest fix.
