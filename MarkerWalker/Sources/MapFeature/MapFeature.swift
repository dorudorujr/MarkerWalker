//
//  MapFeature.swift
//  MarkerWalker
//
//  Created by Claude Code on 2026/01/04.
//

import ComposableArchitecture
import CoreLocation
import Foundation
import LocationClient
import MapKit
import SwiftUI

@Reducer
public struct MapFeature {
    @ObservableState
    public struct State: Equatable {
        public var currentLocation: CLLocation?
        public var cameraPosition: MapCameraPosition = .automatic
        public var authorizationStatus: CLAuthorizationStatus = .notDetermined

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case onDisappear
        case locationUpdated(CLLocation)
        case authorizationStatusChanged(CLAuthorizationStatus)
    }

    private enum CancelID {
        case authorization
        case locationUpdates
    }

    @Dependency(\.locationClient)
    var locationClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                let locationClient = self.locationClient
                let status = locationClient.authorizationStatus()
                state.authorizationStatus = status

                switch status {
                case .notDetermined:
                    return .run { @MainActor send in
                        let stream = locationClient.authorizationStream()
                        await locationClient.requestWhenInUseAuthorization()
                        for await newStatus in stream {
                            send(.authorizationStatusChanged(newStatus))
                            if newStatus != .notDetermined {
                                break
                            }
                        }
                    }
                    .cancellable(
                        id: CancelID.authorization,
                        cancelInFlight: true
                    )
                case .authorizedWhenInUse, .authorizedAlways:
                    return startLocationUpdates()
                case .denied, .restricted:
                    return .none
                @unknown default:
                    return .none
                }

            case .onDisappear:
                let locationClient = self.locationClient
                return .merge(
                    .cancel(id: CancelID.authorization),
                    .cancel(id: CancelID.locationUpdates),
                    .run { _ in
                        await locationClient.stopUpdatingLocation()
                    }
                )

            case .locationUpdated(let location):
                state.currentLocation = location
                state.cameraPosition = .region(
                    MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
                return .none

            case .authorizationStatusChanged(let status):
                state.authorizationStatus = status
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    return startLocationUpdates()
                case .denied, .restricted:
                    let locationClient = self.locationClient
                    return .merge(
                        .cancel(id: CancelID.locationUpdates),
                        .run { _ in
                            await locationClient.stopUpdatingLocation()
                        }
                    )
                case .notDetermined:
                    return .none
                @unknown default:
                    return .none
                }

            }
        }
    }

    private func startLocationUpdates() -> Effect<Action> {
        let locationClient = self.locationClient
        return .run { @MainActor send in
            await locationClient.startUpdatingLocation()
            for await location in locationClient.locationStream() {
                send(.locationUpdated(location))
            }
        }
        .cancellable(id: CancelID.locationUpdates, cancelInFlight: true)
    }
}
