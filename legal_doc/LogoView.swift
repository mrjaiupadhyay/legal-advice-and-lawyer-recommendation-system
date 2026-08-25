//
//  LogoView.swift
//  legal_doc
//
//  Reusable logo component for the app
//

import SwiftUI
import UIKit

struct LogoView: View {
    var size: CGFloat = 120
    var showFallback: Bool = true
    
    var body: some View {
        Group {
            // Try to load the logo image
            if let _ = UIImage(named: "AppLogo") {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipped()
            } else if showFallback {
                // Fallback to system icon if logo not found
                Image(systemName: "scale.3d")
                    .font(.system(size: size * 0.67))
                    .foregroundColor(.blue)
            }
        }
    }
}
