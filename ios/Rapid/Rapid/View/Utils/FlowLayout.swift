//
//  FlowLayoutView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/09.
//

import Foundation
import SwiftUI

struct Flow: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Self.Cache) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = .zero, y: CGFloat = .zero, rowHeight: CGFloat = .zero
        var requiredWidth: CGFloat = .zero
        
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > .zero, x + s.width > maxWidth {
                y += rowHeight + rowSpacing
                requiredWidth = max(requiredWidth, x - spacing)
                x = .zero
                rowHeight = .zero
            }
            x += (x == .zero ? .zero : spacing) + s.width
            rowHeight = max(rowHeight, s.height)
        }
        
        if x > .zero { requiredWidth = max(requiredWidth, x) }
        let totalHeight = y + (x > .zero ? rowHeight : .zero)
        return .init(width: proposal.width ?? requiredWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews subViews: Subviews, cache: inout Self.Cache) {
        let maxWidth = bounds.width
        var x: CGFloat = .zero, y: CGFloat = .zero, rowHeight: CGFloat = .zero
        var row: [Int] = []
        
        func flushRow() {
            guard !row.isEmpty else { return }
            
            let rowWidth = row.reduce(CGFloat(0)) { partialResult, i in
                let w = subViews[i].sizeThatFits(.unspecified).width
                return partialResult + (partialResult == .zero ? .zero : spacing) + w
            }
            
            let startX: CGFloat = {
                switch alignment {
                case .center: return (maxWidth - rowWidth) / 2
                case .trailing: return maxWidth - rowWidth
                default: return .zero
                }
            }()
            
            var cursorX = bounds.minX + startX
            for i in row {
                let s = subViews[i].sizeThatFits(.unspecified)
                let py = bounds.minY + y + (rowHeight - s.height) / 2
                subViews[i].place(at: .init(x: cursorX, y: py), proposal: ProposedViewSize(s))
                cursorX += s.width + spacing
            }
            y += rowHeight + rowSpacing
            rowHeight = .zero
            row.removeAll()
            x = .zero
        }
        
        for i in subViews.indices {
            let s = subViews[i].sizeThatFits(.unspecified)
            if x > 0, x + s.width > maxWidth { flushRow() }
            x += (x == .zero ? .zero : spacing) + s.width
            rowHeight = max(rowHeight, s.height)
            row.append((i))
        }
        flushRow()
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews subViews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subViews: subViews, proposal: proposal)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subViews: subviews, proposal: proposal)
        for (index, subview) in subviews.enumerated() {
            let point = result.offsets[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    
    private func layout(subViews: Subviews, proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .zero
        var currentX: CGFloat = .zero
        var currentY: CGFloat = .zero
        var lineHeight: CGFloat = .zero
        var offsets: [CGPoint] = []
        var maxFinalWidth: CGFloat = .zero
        
        for subView in subViews {
            let size = subView.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = .zero
            }
            
            offsets.append(CGPoint(x: currentX, y: currentY))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxFinalWidth = max(maxFinalWidth, currentX)
        }
        
        return (offsets, CGSize(width: maxFinalWidth, height: currentY + lineHeight))
    }
}

