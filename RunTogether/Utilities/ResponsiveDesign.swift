//
//  ResponsiveDesign.swift
//  RunTogether
//
//  Responsive design utilities for various screen sizes
//

import SwiftUI

/// Screen size categories for responsive design
enum ScreenSize {
    case small      // iPhone SE, iPhone 8
    case medium     // iPhone 12, iPhone 13, iPhone 14
    case large      // iPhone 12 Pro Max, iPhone 14 Pro Max
    case extraLarge // Future devices
    
    static var current: ScreenSize {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        
        // Use the smaller dimension (width in portrait)
        let size = min(width, height)
        
        switch size {
        case ..<375:
            return .small
        case 375..<414:
            return .medium
        case 414..<430:
            return .large
        default:
            return .extraLarge
        }
    }
}

/// Responsive spacing and sizing utilities
struct ResponsiveLayout {
    static let screenSize = ScreenSize.current
    
    /// Horizontal padding based on screen size
    static var horizontalPadding: CGFloat {
        switch screenSize {
        case .small:
            return 16
        case .medium:
            return 20
        case .large, .extraLarge:
            return 24
        }
    }
    
    /// Vertical spacing between sections
    static var sectionSpacing: CGFloat {
        switch screenSize {
        case .small:
            return 16
        case .medium:
            return 20
        case .large, .extraLarge:
            return 24
        }
    }
    
    /// Card padding
    static var cardPadding: CGFloat {
        switch screenSize {
        case .small:
            return 12
        case .medium:
            return 16
        case .large, .extraLarge:
            return 20
        }
    }
    
    /// Button height
    static var buttonHeight: CGFloat {
        switch screenSize {
        case .small:
            return 44
        case .medium:
            return 48
        case .large, .extraLarge:
            return 52
        }
    }
    
    /// Title font size
    static var titleFontSize: CGFloat {
        switch screenSize {
        case .small:
            return 40
        case .medium:
            return 48
        case .large, .extraLarge:
            return 56
        }
    }
    
    /// Headline font size
    static var headlineFontSize: CGFloat {
        switch screenSize {
        case .small:
            return 16
        case .medium:
            return 18
        case .large, .extraLarge:
            return 20
        }
    }
    
    /// Bottom tab bar padding
    static var bottomTabBarPadding: CGFloat {
        switch screenSize {
        case .small:
            return 80
        case .medium:
            return 90
        case .large, .extraLarge:
            return 100
        }
    }
    
    /// Safe area top padding
    static var safeAreaTopPadding: CGFloat {
        return UIApplication.shared.windows.first?.safeAreaInsets.top ?? 44
    }
    
    /// Safe area bottom padding
    static var safeAreaBottomPadding: CGFloat {
        return UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

/// View extension for responsive modifiers
extension View {
    /// Apply responsive horizontal padding
    func responsiveHorizontalPadding() -> some View {
        self.padding(.horizontal, ResponsiveLayout.horizontalPadding)
    }
    
    /// Apply responsive section spacing
    func responsiveSectionSpacing() -> some View {
        self.padding(.vertical, ResponsiveLayout.sectionSpacing)
    }
    
    /// Apply responsive card padding
    func responsiveCardPadding() -> some View {
        self.padding(ResponsiveLayout.cardPadding)
    }
}
