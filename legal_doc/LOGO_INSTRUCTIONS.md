# Adding Logo to Pocket Lawyer App

## Instructions

To add your logo to the app:

1. **Prepare your logo images:**
   - Create three versions of your logo:
     - `AppLogo.png` (1x - standard resolution)
     - `AppLogo@2x.png` (2x - for Retina displays)
     - `AppLogo@3x.png` (3x - for high-resolution displays)
   - Recommended sizes:
     - 1x: 120x120 pixels
     - 2x: 240x240 pixels
     - 3x: 360x360 pixels
   - Format: PNG with transparent background (recommended)

2. **Add images to Xcode:**
   - Open your project in Xcode
   - Navigate to `legal_doc/Assets.xcassets/AppLogo.imageset/`
   - Drag and drop your three logo images into this folder:
     - `AppLogo.png`
     - `AppLogo@2x.png`
     - `AppLogo@3x.png`

3. **Verify:**
   - The logo will automatically appear in:
     - Role Selection Screen (main screen)
     - Client Login Screen
     - Lawyer Login Screen
   - If the logo images are not found, the app will fall back to system icons

## Logo Usage

The logo is used in the following locations:
- **RoleSelectionView**: Main app entry screen (120x120)
- **ClientLoginView**: Client login screen (100x100)
- **LawyerLoginView**: Lawyer login screen (100x100)

## Notes

- The logo asset is already configured in the app
- The code will automatically detect if the logo exists and use it
- If no logo is found, system icons will be displayed as fallback
- Make sure your logo has a transparent background for best appearance
