//
//  VectorTextField.swift
//  Vector
//
//  Created by Avelina Maksimchik on 29.08.2026.
//

import SwiftUI

struct VectorTextField: View {
    
    let icon: String?
    let iconColor: VectorColor
    let iconSize: Double
    let placeholder: String
    let borderColor: VectorColor
    let backgroundColor: VectorColor
    let isSecure: Bool
    let borderWidth: Double
    let height: Double
    let cornerRadius: Double

    @Binding var text: String
    
    init(icon: String? = nil,
         iconColor: VectorColor = .grey01,
         iconSize: Double = 18,
         placeholder: String,
         borderColor: VectorColor = .grey01,
         backgroundColor: VectorColor = .white,
         isSecure: Bool = false,
         borderWidth: Double = 1,
         text: Binding<String>,
         height: Double = 50,
         cornerRadius: Double = 15) {
        self.icon = icon
        self.iconColor = iconColor
        self.iconSize = iconSize
        self.placeholder = placeholder
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
        self.isSecure = isSecure
        self.borderWidth = borderWidth
        self._text = text
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    
    var body: some View {
        
        HStack(spacing: 12){
            
            if let icon = icon{
              
                    Image(systemName: icon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(iconColor.color)
                }
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    
                    TextField(placeholder, text: $text)
                
                
            }}
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: cornerRadius).fill(backgroundColor.color))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(borderColor.color.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.08),
                radius: 8,
                x: 0,
                y: 3)
    }
}

#Preview {
    VectorTextField(icon: "person",
                    iconColor: .grey01,
                    iconSize: 18.0,
                    placeholder: "Имя",
                    borderColor: .grey01,
                    backgroundColor: .white,
                    isSecure: false,
                    text: .constant(""),
                    height: 50,
                    cornerRadius: 15)
}
