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
        
        var color: Color {
            switch self {
            case .white:
                return .white
            case .black:
                return .black
            case .blue01:
                return .systemBlue01
            
            
            }
        }
        
    }
