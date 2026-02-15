//
//  MapView.swift
//  MarkerWalker
//
//  Created by Claude Code on 2026/01/04.
//

import ComposableArchitecture
import MapKit
import SwiftUI

public struct MapView: View {
    @Bindable var store: StoreOf<MapFeature>

    public init(store: StoreOf<MapFeature>) {
        self.store = store
    }

    public var body: some View {
        Map(position: $store.cameraPosition) {
            if let location = store.currentLocation {
                Annotation("", coordinate: location.coordinate) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 3)
                        )
                }
            }
        }
        .mapStyle(.standard)
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    MapView(
        store: Store(
            initialState: MapFeature.State()
        ) {
            MapFeature()
        }
    )
}
