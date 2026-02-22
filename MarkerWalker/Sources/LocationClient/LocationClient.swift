//
//  LocationClient.swift
//  MarkerWalker
//
//  Created by Claude Code on 2026/01/04.
//

import ComposableArchitecture
import CoreLocation
import Foundation
import os

// liveValueなどの変更される可能性のあるstaticプロパティを扱うにはSendableに準拠する必要がある
@DependencyClient
public struct LocationClient: Sendable {
    // Sendableに準拠するにはstored propertyもSendableである必要がある
    public var authorizationStatus: @Sendable () -> CLAuthorizationStatus = { .notDetermined }
    public var requestWhenInUseAuthorization: @Sendable () async -> Void
    public var authorizationStream: @Sendable () -> AsyncStream<CLAuthorizationStatus> = { .finished }
    public var locationStream: @Sendable () -> AsyncStream<CLLocation> = { .finished }
    public var startUpdatingLocation: @Sendable () async -> Void
    public var stopUpdatingLocation: @Sendable () async -> Void
}

extension LocationClient: DependencyKey {
    public static let liveValue: LocationClient = {
        let manager = LocationManager.shared
        return LocationClient(
            authorizationStatus: {
                manager.authorizationStatus
            },
            requestWhenInUseAuthorization: {
                await manager.requestWhenInUseAuthorization()
            },
            authorizationStream: {
                manager.authorizationStream
            },
            locationStream: {
                manager.locationStream
            },
            startUpdatingLocation: {
                await manager.startUpdatingLocation()
            },
            stopUpdatingLocation: {
                await manager.stopUpdatingLocation()
            }
        )
    }()

    public static let testValue = Self()
}

extension DependencyValues {
    public var locationClient: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}

// MARK: - IdentifiedContinuation

/// continuationとUUIDをペアで管理する。
/// onTerminationで旧購読が現在の購読のcontinuationをnil化する論理的レース条件を、
/// UUID比較により防止する。
private struct IdentifiedContinuation<Element: Sendable>: Sendable {
    let continuation: AsyncStream<Element>.Continuation
    let id: UUID
}

// MARK: - LocationManager

/// CLLocationManagerがメインスレッドじゃないといけないためMainActor指定
@MainActor
private final class LocationManager: NSObject {
    static let shared = LocationManager()

    private let manager = CLLocationManager()

    // 同期参照用のキャッシュ（スレッドセーフ）
    private let _authorizationStatus = OSAllocatedUnfairLock(initialState: CLAuthorizationStatus.notDetermined)
    private let _locationContinuation =
        OSAllocatedUnfairLock<IdentifiedContinuation<CLLocation>?>(initialState: nil)
    private let _authorizationContinuation =
        OSAllocatedUnfairLock<IdentifiedContinuation<CLAuthorizationStatus>?>(initialState: nil)

    // nonisolated で同期的にアクセス可能
    nonisolated var authorizationStatus: CLAuthorizationStatus {
        _authorizationStatus.withLock { $0 }
    }

    // 単一購読を前提とした設計。新しい購読が開始されると既存の購読は無効化される。
    nonisolated var authorizationStream: AsyncStream<CLAuthorizationStatus> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            _authorizationContinuation.withLock {
                $0 = IdentifiedContinuation(continuation: continuation, id: id)
            }
            continuation.onTermination = { [_authorizationContinuation] _ in
                _authorizationContinuation.withLock {
                    if $0?.id == id { $0 = nil }
                }
            }
        }
    }

    nonisolated var locationStream: AsyncStream<CLLocation> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            _locationContinuation.withLock {
                $0 = IdentifiedContinuation(continuation: continuation, id: id)
            }
            continuation.onTermination = { [_locationContinuation] _ in
                _locationContinuation.withLock {
                    if $0?.id == id { $0 = nil }
                }
            }
        }
    }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // 初期状態をキャッシュに設定
        let initialStatus = manager.authorizationStatus
        _authorizationStatus.withLock { $0 = initialStatus }
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    // CLLocationManagerDelegateがMainActor外からも呼ばれる可能性があるためnonisolated
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        _authorizationStatus.withLock { $0 = status }
        _authorizationContinuation.withLock {
            _ = $0?.continuation.yield(status)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        _locationContinuation.withLock {
            _ = $0?.continuation.yield(location)
        }
    }
}
