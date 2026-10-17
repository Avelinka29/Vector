//
//  SplashView.swift
//  Vector
//
//  Created by Avelina Maksimchik on 12.08.2026.
//

import SwiftUI

struct SplashView: View {
    
    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    
    var body: some View {
        
        
        ZStack {
            GeometryReader { geometry in
                    
                    ZStack {
                        
                        // Верхняя большая стрелка
                        AnimatedVectorArrow(
                            width: 300,
                            height: 180,
                            color: .blue01,
                            opacity: 0.75,
                            duration: 4.5,
                            delay: 0
                        )
                        .position(
                            x: geometry.size.width * 0.18,
                            y: geometry.size.height * 0.30
                        )
                        
                        // Верхняя правая
                        AnimatedVectorArrow(
                            width: 170,
                            height: 100,
                            color: .blue02,
                            opacity: 0.45,
                            duration: 3.5,
                            delay: 1.2
                        )
                        .position(
                            x: geometry.size.width * 0.65,
                            y: geometry.size.height * 0.27
                        )
                        
                        // Нижняя левая
                        AnimatedVectorArrow(
                            width: 240,
                            height: 145,
                            color: .blue01,
                            opacity: 0.55,
                            duration: 4,
                            delay: 0.7
                        )
                        .position(
                            x: geometry.size.width * 0.18,
                            y: geometry.size.height * 0.75
                        )
                        
                        // Нижняя правая
                        AnimatedVectorArrow(
                            width: 180,
                            height: 110,
                            color: .blue02,
                            opacity: 0.35,
                            duration: 3.8,
                            delay: 1.8
                        )
                        .position(
                            x: geometry.size.width * 0.65,
                            y: geometry.size.height * 0.78
                        )
                    }
            }

            VStack {
                    
                    Spacer()
                    
                    //Logo
                    Image("logo")
                        .resizable()
                        .frame(width: 220, height: 186)
                        .scaleEffect(showLogo ? 1 : 0.7)
                        .opacity(showLogo ? 1 : 0)
                    
                    
                    //Title
                    Text("Vector")
                        .font(.system(size: 65, weight: .medium))
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 15)
                    
                    //Subtitle
                    Text("Выбери направление \n своего будущего")
                        .font(.system(size: 20, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.systemBlue01)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 4)
                        .padding(.top, 3)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 15)
                    
                    Spacer()
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)
        ) {
            showLogo = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.5)){
                showTitle = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.5)){
                showSubtitle = true
            }
        }
        
    }
    
    
}

#Preview {
    SplashView()
}
