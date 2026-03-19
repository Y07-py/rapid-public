//
//  ChatRoomLocationListView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/08.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct ChatRoomLocationListView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var chatRoomViewModel: ChatRoomViewModel
    
    @State private var place: GooglePlacesSearchPlaceWrapper? = nil
    
    var body: some View {
        ZStack {
            Color.secondaryBackgroundColor.ignoresSafeArea()
            VStack(alignment: .center, spacing: .zero) {
                if let selectedChatRoom = chatViewModel.selectedChatRoom {
                    let locations = selectedChatRoom.places
                    if locations.count > 1 {
                        LocationListRootView(places: locations)
                            .environmentObject(chatViewModel)
                            .environmentObject(chatRoomViewModel)
                    } else {
                        ChatRoomLocationDetailView(selectedPlace: $place, viewType: .one)
                            .environmentObject(chatRoomViewModel)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            guard let locations = self.chatViewModel.selectedChatRoom?.places else { return }
            if locations.count == 1 {
                self.place = locations.first
            }
        }
    }
}


enum LocationListRoot: Equatable {
    case list
    case detail
}

private struct LocationListRootView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var chatRoomViewModel: ChatRoomViewModel
    @StateObject private var rootViewModel = RootViewModel<LocationListRoot>(root: .list)
    
    let places: [GooglePlacesSearchPlaceWrapper]
    
    @State private var selectedPlace: GooglePlacesSearchPlaceWrapper? = nil
    
    var body: some View {
        ZStack {
            RootViewController(rootViewModel: rootViewModel) { root in
                switch root {
                case .list: LocationListView(places: places, selectedPlace: $selectedPlace)
                case .detail: ChatRoomLocationDetailView(selectedPlace: $selectedPlace, viewType: .list)
                }
            }
            .environmentObject(rootViewModel)
            .environmentObject(chatViewModel)
            .environmentObject(chatRoomViewModel)
        }
        .navigationBarBackButtonHidden(true)
    }
}

private struct LocationListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var rootViewModel: RootViewModel<LocationListRoot>
    
    let places: [GooglePlacesSearchPlaceWrapper]
    
    @Binding var selectedPlace: GooglePlacesSearchPlaceWrapper?
    
    var body: some View {
        ZStack {
            Color.secondaryBackgroundColor.ignoresSafeArea()
            
            VStack(alignment: .center, spacing: .zero) {
                // Header with close button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black.opacity(0.8))
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    Text("スポット一覧")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                        .padding(.trailing, 40) // Balance the xmark
                        
                    Spacer()
                }
                .frame(height: 60)
                .background(Color.secondaryBackgroundColor)
                .zIndex(1)
                
                ScrollView(.vertical) {
                    VStack(alignment: .center, spacing: 10) {
                        ForEach(places) { place in
                            locationCardView(place: place)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
    
    @ViewBuilder
    private func locationCardView(place: GooglePlacesSearchPlaceWrapper) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if let photo = place.place?.photos?.first {
                WebImage(url: photo.buildUrl()) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundStyle(.gray.opacity(0.8))
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .skelton(isActive: true)
                }
                .padding(.leading, 10)
                VStack(alignment: .leading, spacing: 10) {
                    Text(place.place?.displayName?.text ?? "No name")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black.opacity(0.8))
                    Text(place.place?.formattedAddress ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray.opacity(0.8))
                }
                .padding(.trailing, 10)
            } else {
                Image("NoPlaceImage")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .clipped()
                    .padding(.leading, 10)
                VStack(alignment: .leading, spacing: 10) {
                    Text(place.place?.displayName?.text ?? "No name")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black.opacity(0.8))
                    Text(place.place?.formattedAddress ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray.opacity(0.8))
                }
                .padding(.trailing, 10)
            }
        }
        .padding(.horizontal, 10)
        .onTapGesture {
            self.selectedPlace = place
            rootViewModel.push(.detail)
        }
    }
}

enum ChatRoomLocationViewType {
    case list
    case one
}
