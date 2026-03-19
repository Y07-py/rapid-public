//
//  GMSDetailMapViewRepresentable.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/09/24.
//

import Foundation
import SwiftUI
import GoogleMaps
import Combine

public struct GMSDetailMapViewRepresentable: UIViewRepresentable {
    @EnvironmentObject private var locationSelectViewModel: LocationSelectViewModel
    var clLocation: CLLocation
    var zoom: Float
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(
            latitude: clLocation.coordinate.latitude,
            longitude: clLocation.coordinate.longitude,
            zoom: zoom
        )
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        
        let position = CLLocationCoordinate2D(latitude: clLocation.coordinate.latitude,
                                              longitude: clLocation.coordinate.longitude)
        let marker = GMSMarker(position: position)
        marker.icon = UIImage(named: "target")?.resize(width: 30, height: 40)
        marker.map = mapView
        
        context.coordinator.mapView = mapView
        context.coordinator.setupSubscription()
        
        return mapView
    }
    
    public func updateUIView(_ uiView: GMSMapView, context: Context) {
        uiView.animate(toZoom: zoom)
    }
    
    public class Coordinator: NSObject, GMSMapViewDelegate {
        let parent: GMSDetailMapViewRepresentable
        weak var mapView: GMSMapView?
        private var cancellables = Set<AnyCancellable>()
        
        init(parent: GMSDetailMapViewRepresentable) {
            self.parent = parent
        }
        
        public func setupSubscription() {
            parent.locationSelectViewModel.$nearestLocations
                .receive(on: DispatchQueue.main)
                .sink { [weak self] list in
                    guard let self = self, let wrapper = list.last else { return }
                    
                    if let location = wrapper.place.location,
                       let latitude = location.latitude,
                       let longitude = location.longitude {
                        // Update marker position
                        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        let cameraUpdate = GMSCameraUpdate.setTarget(coordinate)
                        self.mapView?.animate(with: cameraUpdate)
                        
                        self.updateMarker(at: coordinate)
                    }
                }
                .store(in: &cancellables)
        }
        
        private func updateMarker(at coor: CLLocationCoordinate2D) {
            let marker = GMSMarker(position: coor)
            marker.map = mapView
        }
        
        public func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            Task { @MainActor in
                parent.locationSelectViewModel.selectedNearestWrapper = nil
                
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                parent.locationSelectViewModel.tappedNearestPlaceMarker(
                    latitude: marker.position.latitude,
                    longitude: marker.position.longitude
                )
            }
         
            return false
        }
        
        public func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                parent.locationSelectViewModel.selectedNearestWrapper = nil
            }
        }
    }
}

public struct GMSDetailMapStaticViewRepresentable: UIViewRepresentable {
    var clLocation: CLLocation
    var zoom: Float
    
    public func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(
            latitude: clLocation.coordinate.latitude,
            longitude: clLocation.coordinate.longitude,
            zoom: zoom
        )
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        
        // Disable user operation.
        mapView.settings.scrollGestures = false
        mapView.settings.zoomGestures = false
        mapView.settings.tiltGestures = false
        mapView.settings.rotateGestures = false
        mapView.settings.consumesGesturesInView = false
        
        let position = CLLocationCoordinate2D(latitude: clLocation.coordinate.latitude,
                                              longitude: clLocation.coordinate.longitude)
        let marker = GMSMarker(position: position)
        marker.icon = UIImage(named: "target")?.resize(width: 30, height: 40)
        marker.map = mapView
        
        return mapView
    }
    
    public func updateUIView(_ uiView: GMSMapView, context: Context) {
        uiView.animate(toZoom: zoom)
    }
}

