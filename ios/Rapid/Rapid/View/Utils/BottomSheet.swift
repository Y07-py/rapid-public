//
//  BottomSheet.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/13.
//

import SwiftUI
import UIKit

public enum SheetDetent: Equatable {
    case fraction(CGFloat)
    case absolute(CGFloat)
}

public struct BottomSheetHost<Content: View>: UIViewControllerRepresentable {
    /// This structure aims to build a UI that enables operations similar to the sheet modifier, while differing
    /// from that modifier by rendering views on the same level as other views. This resolves the issues inherent in
    /// traditional sheets where views whose height can be changed would overlap other views, enabling the
    /// construction of more flexible layouts.
    
    @Binding var isPresented: Bool
    @Binding var fraction: SheetDetent
    let detents: [SheetDetent]
    let initial: SheetDetent?
    let dismissOnBackdropTap: Bool
    let content: () -> Content
    
    public init(
        isPresented: Binding<Bool>,
        fraction: Binding<SheetDetent>,
        detents: [SheetDetent],
        initial: SheetDetent? = nil,
        dismissOnBackgroundTap: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self._fraction = fraction
        self.detents = detents
        self.initial = initial
        self.dismissOnBackdropTap = dismissOnBackgroundTap
        self.content = content
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> ContentViewController {
        let viewController = ContentViewController()
        viewController.configure(detents: detents, initial: initial, dismissOnBackdropTap: dismissOnBackdropTap, rootView: AnyView(content()))
        viewController.delegate = context.coordinator
        return viewController
    }
    
    public func updateUIViewController(_ uiViewController: ContentViewController, context: Context) {
        uiViewController.updateContent(AnyView(content()))
        uiViewController.setPresented(isPresented)
        uiViewController.onDismiss = { isPresented = false }
        
        // when update fraction, reflecting it in the view.
        uiViewController.updateHeight(fraction)
    }
    
    public final class Coordinator {
        var parent: BottomSheetHost
        
        init(_ parent: BottomSheetHost) {
            self.parent = parent
        }
        
        func reportFraction(_ f: CGFloat) {
            withAnimation {
                parent.fraction = SheetDetent.fraction(f)
            }
        }
    }
    
    final public class ContentViewController: UIViewController {
        weak var delegate: Coordinator?
        private let backdrop = UIView()
        private let surface = UIView()
        public var heightConstraint: NSLayoutConstraint!
        
        private var hosting: UIHostingController<AnyView>?
        private var detentHeights: [CGFloat] = []
        private var initialHeight: CGFloat?
        private var isShown: Bool = false
        public var onDismiss: (() -> Void)?
        private var pan: UIPanGestureRecognizer!
        private var startHeight: CGFloat = .zero
        private var filterDy: CGFloat = 0
        
        public override func loadView() {
            view = PassthroughContainerView()
        }
        
        func configure(detents: [SheetDetent], initial: SheetDetent?, dismissOnBackdropTap: Bool, rootView: AnyView) {
            (view as? PassthroughContainerView)?.surface = surface
            
            view.backgroundColor = .clear
            backdrop.backgroundColor = .clear
            backdrop.alpha = .zero
            backdrop.isUserInteractionEnabled = true
            
            surface.backgroundColor = .clear
            surface.clipsToBounds = true
            surface.isUserInteractionEnabled = true
            surface.layer.cornerCurve = .continuous
            surface.layer.cornerRadius = 16
            surface.layer.masksToBounds = true
            
            let host = UIHostingController(rootView: rootView)
            host.view.backgroundColor = .systemBackground
            addChild(host)
            surface.addSubview(host.view)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: surface.topAnchor, constant: .zero),
                host.view.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
            ])
            host.didMove(toParent: self)
            hosting = host
            
            view.addSubview(backdrop)
            view.addSubview(surface)
            backdrop.translatesAutoresizingMaskIntoConstraints = false
            surface.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                backdrop.topAnchor.constraint(equalTo: view.topAnchor),
                backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                
                surface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                surface.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                surface.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            heightConstraint = surface.heightAnchor.constraint(equalToConstant: .zero)
            heightConstraint.isActive = true
            
            let grabber = UIView()
            grabber.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.4)
            grabber.layer.cornerRadius = 2.5
            surface.addSubview(grabber)
            grabber.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                grabber.topAnchor.constraint(equalTo: surface.topAnchor, constant: 8),
                grabber.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
                grabber.widthAnchor.constraint(equalToConstant: 44),
                grabber.heightAnchor.constraint(equalToConstant: 5)
            ])
            
            pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            surface.addGestureRecognizer(pan)
            
            self.detentHeights = detents.map { Self.resolve($0, container: 1) }
            if let i = initial { self.initialHeight = Self.resolve(i, container: 1) }
        }
        
        public override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            let H: CGFloat = UIWindow().bounds.height
            guard H > 0 else { return }
            detentHeights = detentHeights.map { $0 <= 1 ? min(H, $0 * H) : min(H, $0) }
            if let ih = initialHeight {
                initialHeight = ih <= 1 ? min(H,  ih * H) : min(H, ih)
            }
        }
        
        public func updateContent(_ view: AnyView) {
            hosting?.rootView = view
        }
        
        public func setPresented(_ presented: Bool) {
            guard presented != isShown else { return }
            isShown = presented
            
            view.layoutIfNeeded()
            let H = view.bounds.height
            let targetOpen = initialHeight ?? (detentHeights.sorted().last ?? H)
            
            if presented {
                heightConstraint.constant = 0
                view.layoutIfNeeded()
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: 0.9,
                    initialSpringVelocity: 0.6,
                    options: [.allowUserInteraction, .beginFromCurrentState]
                ) {
                    self.backdrop.alpha = 1
                    self.heightConstraint.constant = targetOpen
                    self.view.layoutIfNeeded()
                }
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                    self.backdrop.alpha = 0
                    self.heightConstraint.constant = 0
                    self.view.layoutIfNeeded()
                } completion: { _ in
                    self.onDismiss?()
                }
            }
        }
        
        public func updateHeight(_ detent: SheetDetent, animated: Bool = true) {
            var constant: CGFloat
            
            switch detent {
            case .fraction(let f):
                let viewHeight = view.bounds.height
                let target = max(0, min(1, f)) * viewHeight
                constant = target
            case .absolute(let h):
                constant = h
            }
            
            let updateHeight = {
                self.heightConstraint.constant = constant
                self.view.layoutIfNeeded()
            }
            
            if animated {
                UIView.animate(withDuration: 0.25, delay: .zero) {
                    updateHeight()
                }
            } else {
                updateHeight()
            }
        }
        
        private func nearestIndex(to height: CGFloat) -> Int {
            let heights = detentHeights.sorted()
            guard !heights.isEmpty else { return 0 }
            var best = 0
            var bestDiff = CGFloat.greatestFiniteMagnitude
            for (i, h) in heights.enumerated() {
                let diff = abs(h - height)
                if diff < bestDiff {
                    bestDiff = diff
                    best = i
                }
            }
            return best
        }
        
        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            // prevent the view from being overlay sensitive to swipes.
            let dy = g.translation(in: surface).y
            filterDy = 0.2 * dy + 0.8 * filterDy
      
            switch g.state {
            case .began:
                startHeight = heightConstraint.constant
                filterDy = 0
            case .changed:
                UIView.animate(withDuration: 0.25) {
                    let newH = max(0, self.startHeight - self.filterDy)
                    self.heightConstraint.constant = newH
                    self.view.layoutIfNeeded()
                }
            case .ended, .cancelled:
                let heights = detentHeights.sorted()
                guard !heights.isEmpty else { return }
                let startIndex = nearestIndex(to: startHeight)
                var nextIndex = startIndex
                if dy < 0 {
                    nextIndex = min(detentHeights.count - 1, nextIndex + 1)
                } else {
                    nextIndex = max(0, nextIndex - 1)
                }
                let snapped = heights[nextIndex]
                let fraction = snapped / UIWindow().bounds.height
                delegate?.reportFraction(fraction)
                UIView.animate(withDuration: 0.25, delay: .zero, options: [.curveEaseInOut, .allowUserInteraction]) {
                    self.heightConstraint.constant = snapped
                    self.view.layoutIfNeeded()
                    self.backdrop.alpha = 0
                }
            default:
                break
            }
        }
        
        private static func resolve(_ d: SheetDetent, container: CGFloat) -> CGFloat {
            switch d {
            case .fraction(let f): return max(0, min(1, f))
            case .absolute(let h): return h
            }
        }
    }
}

final public class PassthroughContainerView: UIView {
    weak var surface: UIView?
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let surface = surface else { return false }
        let point = convert(point, to: surface)
        return surface.point(inside: point, with: event)
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let surface = surface else { return nil }
        let point = convert(point, to: surface)
        return surface.point(inside: point, with: event) ? surface.hitTest(point, with: event) : nil
    }
}
