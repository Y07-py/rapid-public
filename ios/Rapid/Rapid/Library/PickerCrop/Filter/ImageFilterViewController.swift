//
//  ImageFilterViewController.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/16.
//

import Foundation
import UIKit
import SwiftUI
import CoreImage

protocol IsMediaFilter: AnyObject {
    var didSave: ((PickerCropMediaItem) -> Void)? { get set }
    var didCancel: (() -> Void)? { get set }
}

class ImageFilterViewController: UIViewController, IsMediaFilter, UIGestureRecognizerDelegate {
    
    public var inputPhoto: PickerCropPhoto!
    public var isFromSelectionVC: Bool = false
    
    public var didSave: ((PickerCropMediaItem) -> Void)?
    public var didCancel: (() -> Void)?
    
    private let filters: [ImageFilter] = [
        ImageFilter(name: "Normal", applier: nil),
        ImageFilter(name: "Nashville", applier: ImageFilter.nashvilleFilter),
        ImageFilter(name: "Toaster", applier: ImageFilter.toasterFilter),
        ImageFilter(name: "1977", applier: ImageFilter.apply1977Filter),
        ImageFilter(name: "Clarendon", applier: ImageFilter.clarendonFilter),
        ImageFilter(name: "Chrome", coreImageFilterName: "CIPhotoEffectChrome"),
        ImageFilter(name: "Fade", coreImageFilterName: "CIPhotoEffectFade"),
        ImageFilter(name: "Instant", coreImageFilterName: "CIPhotoEffectInstant"),
        ImageFilter(name: "Mono", coreImageFilterName: "CIPhotoEffectMono"),
        ImageFilter(name: "Noir", coreImageFilterName: "CIPhotoEffectNoir"),
        ImageFilter(name: "Process", coreImageFilterName: "CIPhotoEffectProcess"),
        ImageFilter(name: "Tonal", coreImageFilterName: "CIPhotoEffectTonal"),
        ImageFilter(name: "Transfer", coreImageFilterName: "CIPhotoEffectTransfer"),
        ImageFilter(name: "Tone", coreImageFilterName: "CILinearToSRGBToneCurve"),
        ImageFilter(name: "Linear", coreImageFilterName: "CISRGBToneCurveToLinear"),
        ImageFilter(name: "Sepia", coreImageFilterName: "CISepiaTone"),
        ImageFilter(name: "XRay", coreImageFilterName: "CIXRay"),
    ]
    
    private var selectedFilter: ImageFilter?
    
    private var filteredThumbnailImageArray: [UIImage] = []
    private var thumbnailImageForFiltering: CIImage?
    private var currentlySelectedImageThumbnail: UIImage?
    
    private var imageFilterView = ImageFilterView()
    
    override open func loadView() { view = imageFilterView }
    
    required init(inputPhoto: PickerCropPhoto,
                  isFromSelectionVC: Bool
    ) {
        self.inputPhoto = inputPhoto
        self.isFromSelectionVC = isFromSelectionVC
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageFilterView.imageView.image = inputPhoto.image
        thumbnailImageForFiltering = thumbFromImage(inputPhoto.image)
        DispatchQueue.global().async {
            self.filteredThumbnailImageArray = self.filters.map { filter -> UIImage in
                if let applier = filter.applier,
                   let thumbnailImage = self.thumbnailImageForFiltering,
                   let outputImage = applier(thumbnailImage) {
                    return outputImage.toUIImage()
                } else {
                    return self.inputPhoto.originalImage
                }
            }
            DispatchQueue.main.async {
                self.imageFilterView.collectionView.reloadData()
                self.imageFilterView.collectionView.selectItem(at: IndexPath(row: 0, section: 0),
                                                               animated: false,
                                                               scrollPosition: UICollectionView.ScrollPosition.bottom)
                self.imageFilterView.filtersLoader.stopAnimating()
            }
        }
        
        imageFilterView.collectionView.register(ImageFilterCollectionViewCell.self, forCellWithReuseIdentifier: "FilterCell")
        imageFilterView.collectionView.dataSource = self
        imageFilterView.collectionView.delegate = self
        
        imageFilterView.backgroundColor = UIColor.offWhiteOrBlack
        
        setupNavigationBar()
        
        let touchDownGR = UILongPressGestureRecognizer(target: self, action: #selector(handleTouchDown))
        touchDownGR.minimumPressDuration = 0
        touchDownGR.delegate = self
        imageFilterView.imageView.addGestureRecognizer(touchDownGR)
        imageFilterView.imageView.isUserInteractionEnabled = true
        
    }
    
    private func setupNavigationBar() {
        let navigationBar = UINavigationBar()
        navigationBar.prefersLargeTitles = false

        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .systemBackground
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
        
        let navItem = UINavigationItem()
        
        if isFromSelectionVC {
            let left = UIBarButtonItem(title: "キャンセル",
                                       style: .plain,
                                       target: self,
                                       action: #selector(cancel))
            left.setFont(font: PickerCropFonts().leftBarButtonFont, forState: .normal)
            navItem.leftBarButtonItem = left
        }
        
        let right = UIBarButtonItem(title: "完了",
                                    style: .done,
                                    target: self,
                                    action: #selector(save))
        right.tintColor = UIColor.tintColor
        right.setFont(font: PickerCropFonts().rightBarButtonFont, forState: .normal)
        navItem.rightBarButtonItem = right
        
        navigationBar.items = [navItem]
        
        imageFilterView.addSubview(navigationBar)
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: imageFilterView.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: imageFilterView.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: imageFilterView.trailingAnchor)
        ])
    }
    
    private func thumbFromImage(_ img: UIImage) -> CIImage {
        let ratio = img.size.width / img.size.height
        let scale = view.window?.windowScene?.screen.scale ?? 1.0
        let thumbnailHeight: CGFloat = 300 * scale
        let thumbnailWidth = thumbnailHeight * ratio
        let thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        let smallImage = renderer.image { _ in
            img.draw(in: CGRect(x: 0, y: 0, width: thumbnailWidth, height: thumbnailHeight))
        }
        return CIImage(cgImage: smallImage.cgImage!)
    }
    
    @objc private func handleTouchDown(sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            imageFilterView.imageView.image = inputPhoto.originalImage
        case .ended:
            imageFilterView.imageView.image = currentlySelectedImageThumbnail ?? inputPhoto.originalImage
        default:
            ()
        }
    }
    
    @objc func cancel() {
        didCancel?()
    }
    
    @objc func save() {
        guard let didSave = didSave else { return }
        
        DispatchQueue.global().async {
            if let f = self.selectedFilter,
               let applier = f.applier,
               let ciImage = self.inputPhoto.originalImage.toCIImage(),
               let modifiedFullSizeImage = applier(ciImage) {
                self.inputPhoto.modifiedImage = modifiedFullSizeImage.toUIImage()
            } else {
                self.inputPhoto.modifiedImage = nil
            }
            DispatchQueue.main.async {
                didSave(PickerCropMediaItem.photo(p: self.inputPhoto))
            }
        }
    }
}

extension ImageFilterViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredThumbnailImageArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let filter = filters[indexPath.row]
        let image = filteredThumbnailImageArray[indexPath.row]
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterCell", for: indexPath) as? ImageFilterCollectionViewCell {
            cell.name.text = filter.name
            cell.imageView.image = image
            return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedFilter = filters[indexPath.row]
        currentlySelectedImageThumbnail = filteredThumbnailImageArray[indexPath.row]
        self.imageFilterView.imageView.image = currentlySelectedImageThumbnail
    }
    
}
