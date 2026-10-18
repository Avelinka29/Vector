//
//  VectorButton.swift
//  Vector
//
//  Created by Avelina Maksimchik on 29.08.2026.
//

import SwiftUI

struct VectorButton: View {
    
    let title: String
    let icon: String?
    let backgroundColor: VectorColor
    let isInfinity: Bool
    let action: () -> Void
    
    var body: some View {
        
        Button(action: action)
            {
                Text(title)
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .medium))
                
                
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.white)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .frame(maxWidth: isInfinity ? .infinity : nil)
            .frame(height: 45)
            .background(backgroundColor.color)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.25),
                    radius: 4,
                    x: 0,
                    y: 5)
            .padding(.top, 10)
    }
}

#Preview {
    VectorButton(title: "Войти",
                 icon: "arrow.forward",
                 backgroundColor: .blue01,
                 isInfinity: true)
    {
        print("Нажали")
    }
}
