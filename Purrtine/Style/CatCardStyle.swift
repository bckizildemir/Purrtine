import SwiftUI

enum CatCardVariant {
    case home
    case gallery

    var size: CGSize {
        switch self {
        case .home:    return .init(width: 120, height: 180)
        case .gallery: return .init(width: 160, height: 230)
        }
    }

    var background: some ShapeStyle {
        switch self {
        case .home:    Color(UIColor.tertiarySystemGroupedBackground)
        case .gallery: Color(.secondarySystemGroupedBackground)
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .home:    return 4
        case .gallery: return 8
        }
    }
    
    // Fotoğraf çapı (her varyant için farklı)
    var photoDiameter: CGFloat {
        switch self {
        case .home:    return 72
        case .gallery: return 120
        }
    }
    
    // Başlık fontu (her varyant için farklı)
    var titleFont: Font {
        switch self {
        case .home:    return .system(size: 18, weight: .semibold)
        case .gallery: return .system(size: 22, weight: .bold)
        }
    }
    
    // Alt başlık fontu (her varyant için farklı)
    var subtitleFont: Font {
        switch self {
        case .home:    return .system(size: 14, weight: .regular)
        case .gallery: return .system(size: 16, weight: .medium)
        }
    }
    
    // İçerik padding'i (her varyant için farklı)
    var contentPadding: EdgeInsets {
        switch self {
        case .home:
            return EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)
        case .gallery:
            return EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12)
        }
    }
    
    
    
    
    

    // İsteğe bağlı: fotoğraf çapı, padding, font vs. eklenebilir
} 
