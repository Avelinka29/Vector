//
//  AnimatedVectorArrow.swift
//  Vector
//
//  Created by Avelina Maksimchik on 13.08.2026.
//

import SwiftUI

struct AnimatedVectorArrow: View {
    
    let width: CGFloat
    let height: CGFloat
    let color: VectorColor
    let opacity: Double
    let duration: Double
    let delay: Double
    
    @State private var isMoving = false
    
    var body: some View {
        VectorArrow()
            .stroke(
                LinearGradient(
                    colors: [color.color.opacity(opacity * 0.2), color.color.opacity(opacity)],
                    startPoint: .leading,
                    endPoint: .trailing
                ), style: StrokeStyle (lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
            .frame(width: width, height: height)
        
            .offset(x: isMoving ? 180 : -180, y: isMoving ? -100 : 100)
        
            .animation(.easeInOut(duration: duration).delay(delay), value: isMoving)
            .onAppear{isMoving = true}
    }
}

#Preview {
    AnimatedVectorArrow(
            width: 250,
            height: 150,
            color: .blue01,
            opacity: 0.7,
            duration: 4,
            delay: 0
        )
}
