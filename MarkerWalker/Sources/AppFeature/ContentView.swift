//
//  ContentView.swift
//  MarkerWalker
//
//  Created by 杉岡成哉 on 2026/01/01.
//

import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
