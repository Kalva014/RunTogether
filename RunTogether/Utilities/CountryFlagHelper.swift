//
//  CountryFlagHelper.swift
//  RunTogether
//
//  Utility to convert country names to emoji flags
//

import Foundation

struct CountryFlagHelper {
    
    // MARK: - Country List
    static let countries = [
        "United States", "Canada", "United Kingdom", "Germany", "France", 
        "Italy", "Spain", "Netherlands", "Belgium", "Switzerland",
        "Austria", "Sweden", "Norway", "Denmark", "Finland",
        "Poland", "Czech Republic", "Portugal", "Greece", "Ireland",
        "Australia", "New Zealand", "Japan", "South Korea", "China",
        "India", "Brazil", "Argentina", "Mexico", "Chile",
        "Colombia", "Peru", "South Africa", "Kenya", "Ethiopia",
        "Morocco", "Egypt", "Nigeria", "Jamaica", "Trinidad and Tobago",
        "Russia", "Ukraine", "Turkey", "Israel", "Saudi Arabia",
        "United Arab Emirates", "Singapore", "Malaysia", "Thailand", "Vietnam",
        "Philippines", "Indonesia", "Hong Kong", "Taiwan"
    ].sorted()
    
    // MARK: - Country to Flag Emoji Mapping
    private static let countryToFlag: [String: String] = [
        "United States": "🇺🇸",
        "Canada": "🇨🇦",
        "United Kingdom": "🇬🇧",
        "Germany": "🇩🇪",
        "France": "🇫🇷",
        "Italy": "🇮🇹",
        "Spain": "🇪🇸",
        "Netherlands": "🇳🇱",
        "Belgium": "🇧🇪",
        "Switzerland": "🇨🇭",
        "Austria": "🇦🇹",
        "Sweden": "🇸🇪",
        "Norway": "🇳🇴",
        "Denmark": "🇩🇰",
        "Finland": "🇫🇮",
        "Poland": "🇵🇱",
        "Czech Republic": "🇨🇿",
        "Portugal": "🇵🇹",
        "Greece": "🇬🇷",
        "Ireland": "🇮🇪",
        "Australia": "🇦🇺",
        "New Zealand": "🇳🇿",
        "Japan": "🇯🇵",
        "South Korea": "🇰🇷",
        "China": "🇨🇳",
        "India": "🇮🇳",
        "Brazil": "🇧🇷",
        "Argentina": "🇦🇷",
        "Mexico": "🇲🇽",
        "Chile": "🇨🇱",
        "Colombia": "🇨🇴",
        "Peru": "🇵🇪",
        "South Africa": "🇿🇦",
        "Kenya": "🇰🇪",
        "Ethiopia": "🇪🇹",
        "Morocco": "🇲🇦",
        "Egypt": "🇪🇬",
        "Nigeria": "🇳🇬",
        "Jamaica": "🇯🇲",
        "Trinidad and Tobago": "🇹🇹",
        "Russia": "🇷🇺",
        "Ukraine": "🇺🇦",
        "Turkey": "🇹🇷",
        "Israel": "🇮🇱",
        "Saudi Arabia": "🇸🇦",
        "United Arab Emirates": "🇦🇪",
        "Singapore": "🇸🇬",
        "Malaysia": "🇲🇾",
        "Thailand": "🇹🇭",
        "Vietnam": "🇻🇳",
        "Philippines": "🇵🇭",
        "Indonesia": "🇮🇩",
        "Hong Kong": "🇭🇰",
        "Taiwan": "🇹🇼"
    ]
    
    // MARK: - Get Flag Emoji
    /// Returns the flag emoji for a given country name
    /// - Parameter country: The country name
    /// - Returns: The flag emoji, or 🏳️ if not found
    static func flagEmoji(for country: String?) -> String {
        guard let country = country else { return "🏳️" }
        return countryToFlag[country] ?? "🏳️"
    }
    
    /// Returns the flag emoji for a given country name, with fallback
    /// - Parameters:
    ///   - country: The country name
    ///   - fallback: The fallback emoji to use if country not found
    /// - Returns: The flag emoji or fallback
    static func flagEmoji(for country: String?, fallback: String = "🏳️") -> String {
        guard let country = country else { return fallback }
        return countryToFlag[country] ?? fallback
    }
}
