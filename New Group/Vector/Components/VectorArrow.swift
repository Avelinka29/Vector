//
//  VectorArrow.swift
//  Vector
//
//  Created by Avelina Maksimchik on 13.08.2026.
//

import SwiftUI

struct VectorArrow: Shape {
    func path (in rect: CGRect) -> Path {
        var path = Path()
        
        let start = CGPoint(
            x: rect.minX,
            y: rect.maxY)
        
        let end = CGPoint(
            x: rect.maxX,
            y: rect.minY)
        
        //линия
        path.move(to: start)
        path.addLine(to: end)
        
        
        //наконечник
        let arrowSize = min(rect.width, rect.height) * 0.16
        
        path.move(to: CGPoint(
            x: end.x - arrowSize,
            y: end.y))
        
        path.addLine(to: end)
        path.addLine(to: CGPoint(
            x: end.x,
            y: end.y + arrowSize))
        
        return path
        
    }
}

#Preview {
    VectorArrow()
}
