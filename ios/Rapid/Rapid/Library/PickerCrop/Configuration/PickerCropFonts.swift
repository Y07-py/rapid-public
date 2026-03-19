//
//  PickerCropFonts.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/16.
//

import Foundation
import UIKit

public struct PickerCropFonts {
    public var pickerTitleFont: UIFont = .boldSystemFont(ofSize: 17)
    
    public var libraryWarningFont: UIFont = UIFont(name: "Helvetica Neue", size: 14)!
    
    public var durationFont: UIFont = .systemFont(ofSize: 12)
    
    public var multipleSelectionIndicatorFont: UIFont = .systemFont(ofSize: 12, weight: .regular)
    
    public var albumCellTitleFont: UIFont = .systemFont(ofSize: 16, weight: .regular)
    
    public var albumCellNumberOfItemsFont: UIFont = .systemFont(ofSize: 12, weight: .regular)
    
    public var menuItemFont: UIFont = .systemFont(ofSize: 17, weight: .semibold)
    
    public var filterNameFont: UIFont = .systemFont(ofSize: 11, weight: .regular)
    public var filterSelectionSelectedFont: UIFont = .systemFont(ofSize: 11, weight: .semibold)
    public var filterSelectionUnSelectedFont: UIFont = .systemFont(ofSize: 11, weight: .regular)
    
    public var cameraTimeElapsedFont: UIFont = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    
    public var navigationBarTitleFont: UIFont = .boldSystemFont(ofSize: 17)
    
    public var rightBarButtonFont: UIFont?
    public var leftBarButtonFont: UIFont?
}
