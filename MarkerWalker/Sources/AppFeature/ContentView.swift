//
//  ContentView.swift
//  MarkerWalker
//
//  Created by 杉岡成哉 on 2026/01/01.
//

import ComposableArchitecture
import MapFeature
import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        MapView(
            store: Store(
                initialState: MapFeature.State()
            ) {
                MapFeature()
            }
        )
    }
}

#Preview {
    ContentView()
}
