//
//  ImageFilterView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/16.
//

import Foundation
import Stevia
import UIKit

class ImageFilterView: UIView {
    let imageView = UIImageView()
    var collectionView: UICollectionView!
    var filtersLoader: UIActivityIndicatorView!
    fileprivate let collectionViewContainer: UIView = UIView()
    
    convenience init() {
        self.init(frame: .zero)
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout())
        self.filtersLoader = UIActivityIndicatorView(style: .medium)
        self.filtersLoader.hidesWhenStopped = true
        self.filtersLoader.startAnimating()
        self.filtersLoader.color = .tintColor
        
        subviews(imageView, collectionViewContainer.subviews(filtersLoader, collectionView))
        
        let height = window?.windowScene?.screen.bounds.height ?? .zero
        let isIphone4 = height == 480
        let sideMargin: CGFloat = isIphone4 ? 20 : 0
        
        |-sideMargin-imageView.top(0)-sideMargin-|
        |-sideMargin-collectionViewContainer-sideMargin-|
        collectionViewContainer.bottom(0)
        imageView.Bottom == collectionViewContainer.Top
        |collectionView.centerVertically().height(160)|
        filtersLoader.centerInContainer()
        
        imageView.heightEqualsWidth()
        
        backgroundColor = .offWhiteOrBlack
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
    }
    
    func layout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 4
        layout.sectionInset = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        layout.itemSize = CGSize(width: 100, height: 120)
        return layout
    }
}
