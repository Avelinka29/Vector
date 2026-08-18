//
//  File.swift
//  Vector
//
//  Created by Avelina Maksimchik on 13.08.2026.
//

import SwiftUI
    
    enum VectorColor {
        
        case white
        case black
        case blue01
        case blue02
        case grey01
        case darkBlue
        
        var color: Color {
            switch self {
            case .white:
                return .systemWhite
            case .black:
                return .black
            case .blue01:
                return .systemBlue01
            case . blue02:
                return .systemBlue02
            case .grey01:
                return .systemGrey1
            case .darkBlue:
                return .systemDarkBlue
            
            }
        }
        
    }
