//
//  VectorTextField2.swift
//  Vector
//
//  Created by Avelina Maksimchik on 01.09.2026.
//

import SwiftUI

struct VectorTextField2: View {
    
    let placeholder: String
    let icon: String?
    
    @Binding var text: String
    
    
    init(placeholder: String, icon: String?, text: Binding<String>) {
        self.placeholder = placeholder
        self.icon = icon
        self._text = text
    }
    
    var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            RoundedRectangle(cornerRadius: 18)
                .stroke(.systemGrey1, lineWidth: 1)
                .frame(height: 60)
            
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.systemBlue01)
                }
                
                TextField("", text: $text)
                    .foregroundStyle(.systemDarkBlue)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.leading, 7)
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
            
            
            
            Text(placeholder)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.systemDarkBlue.opacity(0.5))
                .padding(.horizontal, 6)
                .background(.systemWhite)
                .padding(.leading, 45)
                .offset(y: -9)
            
            
            
        }
        
        
        
        
        
    }
}

#Preview {
    VectorTextField2(placeholder: "Фамилия", icon: "person", text: .constant("Иванов"))
}
