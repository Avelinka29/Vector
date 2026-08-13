//
//  SplashView.swift
//  Vector
//
//  Created by Avelina Maksimchik on 12.08.2026.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            
            VStack {
                
                Spacer()
                
                //Logo
                Image("logo")
                    .resizable()
                    .frame(width: 220, height: 186)
                
                
                //Title
                Text("Vector")
                    .font(.system(size: 65, weight: .medium))
                
                //Subtitle
                Text("Выбери направление \n своего будущего")
                    .font(.system(size: 20, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.systemBlue01)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 4)
                    .padding(.top, 3)
                
                Spacer()
            }
        }
    }
}

#Preview {
    SplashView()
}
