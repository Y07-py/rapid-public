//
//  ImageFilterCollectionViewCell.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/16.
//

import Foundation
import UIKit
import Stevia

class ImageFilterCollectionViewCell: UICollectionViewCell {
    let name = UILabel()
    let imageView = UIImageView()
    
    private let fonts = PickerCropFonts()
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.contentView.transform = self.isHighlighted
                ? CGAffineTransform(scaleX: 0.95, y: 0.95)
                : CGAffineTransform.identity
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            name.textColor = isSelected
            ? UIColor.label
            : UIColor.secondaryLabel
            name.font = isSelected
            ? fonts.filterSelectionSelectedFont
            : fonts.filterSelectionUnSelectedFont
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(codeer: ) has not been implemented.")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        subviews(name, imageView)
        
        |name|.top(0)
        |imageView|.bottom(0).heightEqualsWidth()
        
        name.font = fonts.filterNameFont
        name.textColor = UIColor.secondaryLabel
        name.textAlignment = .center
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        self.clipsToBounds = false
        self.layer.shadowColor = UIColor.label.cgColor
        self.layer.shadowOpacity = 0.2
        self.layer.shadowOffset = CGSize(width: 4, height: 7)
        self.layer.shadowRadius = 5
        self.layer.backgroundColor = UIColor.clear.cgColor
    }
}
