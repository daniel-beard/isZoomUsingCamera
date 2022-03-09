//
//  Model.swift
//  isZoomUsingCamera
//
//  Created by Daniel Beard on 3/27/20.
//  Copyright © 2020 dbeard. All rights reserved.
//

import AppKit
import SwiftUI
import Combine
import SwiftShell

// MARK: Types and enums

let DEFAULTS_ENABLE_DND_AUTOMATICALLY = "enable.dnd.auntomatically.v1"

enum CameraSampleResult {
    case noResult
    case usingCamera
    case zoomNotRunning
    case notUsingCamera
    case errorSampling

    func displayText() -> String {
        switch self {
            case .noResult:         return "No result"
            case .usingCamera:      return "Zoom is USING the camera"
            case .notUsingCamera:   return "Zoom is NOT USING the camera"
            case .zoomNotRunning:   return "Zoom does not appear to be running"
            case .errorSampling:    return "Error sampling"
        }
    }
}

enum ScreenSharingSampleResult {
    case notScreenSharing
    case screenSharing

    func displayText() -> String {
        switch self {
        case .notScreenSharing: return "Not screen sharing"
        case .screenSharing:    return "Screen sharing"
        }
    }
}

enum ShortcutsError: Error {
    case canNotRetrieve(String)
}

//MARK: Top level observable

final class Model: ObservableObject {

    @AppStorage("dndOnShortcut") var dndOnShortcutSelection: String = ""
    @AppStorage("dndOffShortcut") var dndOffShortcutSelection: String = ""
    @AppStorage("shouldToggleDND") var dndToggle: Bool = false

    @Published var canShowShortcuts = false

    @Published var textResult: String = "No results" {
        didSet {
            guard dndToggle == true else { return }
            guard oldValue != textResult else { return }
            switch cameraSampleResult {
                case .usingCamera: DNDUtil.enableDND()
                case .notUsingCamera, .zoomNotRunning: DNDUtil.disableDND()
                default: break
            }
        }
    }
    @Published var screensharingText: String = "Not sharing screen"

    let interval: TimeInterval = 1
    private var timer: Timer? = nil
    private var cameraSampleResult: CameraSampleResult = .noResult
    private var screenShareSampleResult: ScreenSharingSampleResult = .notScreenSharing

    @Published var listOfAvailableShortcuts = [String]()
    private var shortcutsProvider = ShortcutsListProvider()

    init() {
        canShowShortcuts = !(NSAppKitVersion.current.rawValue <= NSAppKitVersion.macOS11_4.rawValue)
    }

    func fetchShortcutsList() async {
        do {
            let result = try await shortcutsProvider.run()
            DispatchQueue.main.async { self.listOfAvailableShortcuts = result }
        } catch {
            listOfAvailableShortcuts = ["Could not retrieve list of shortcuts"]
        }
    }

    func start() {
        Task {
            await fetchShortcutsList()
        }
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { [weak self] _ in
            CameraUsageSampleProvider().run(callback: { result in
                DispatchQueue.main.async {
                    self?.cameraSampleResult = result
                    self?.textResult = result.displayText()
                }
            })
            ScreenSharingUsageSampleProvider().run { result in
                DispatchQueue.main.async {
                    self?.screenShareSampleResult = result
                    self?.screensharingText = result.displayText()
                }
            }
        })
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}

// MARK: Zoom providers

struct ScreenSharingUsageSampleProvider {
    let sampleDuration = 0.1
    let sampleFile = "/tmp/zoomsamplescreensharing"
    let sampleSentinel = "capture thread"

    func run(callback: @escaping (ScreenSharingSampleResult) -> Void) {
        DispatchQueue(label: "Sampler").async {

            let zoomApps = NSRunningApplication.runningApplications(withBundleIdentifier: "us.zoom.CptHost")
            guard !zoomApps.isEmpty else {
                callback(.notScreenSharing)
                return
            }

            // Only pick first for now
            //TODO: Technically you can run multiple instances of zoom, but we'll ignore that for now.
            let pid = zoomApps.first!.processIdentifier

            // Sample with PID
            SwiftShell.run(bash: "/usr/bin/sample \(pid) \(self.sampleDuration) -f \(self.sampleFile)")

            // Parse output and return a result. 0 exitCode is a match.
            let exitCode = SwiftShell.run(bash: "/usr/bin/grep '\(self.sampleSentinel)' \(self.sampleFile)").exitcode

            if exitCode == 0 {
                callback(.screenSharing); return
            } else if exitCode == 1 {
                callback(.notScreenSharing); return
            }
        }
    }
}

struct CameraUsageSampleProvider {

    let sampleDuration = 0.1
    let sampleFile = "/tmp/zoomsample"
    let sampleSentinel = "CMIOGraph::DoWork"

    func run(callback: @escaping (CameraSampleResult) -> Void) {
        DispatchQueue(label: "Sampler").async {

            let zoomApps = NSRunningApplication.runningApplications(withBundleIdentifier: "us.zoom.xos")
            guard !zoomApps.isEmpty else {
                callback(.zoomNotRunning)
                return
            }

            // Only pick first for now
            //TODO: Technically you can run multiple instances of zoom, but we'll ignore that for now.
            let pid = zoomApps.first!.processIdentifier

            // Sample with PID
            SwiftShell.run(bash: "/usr/bin/sample \(pid) \(self.sampleDuration) -f \(self.sampleFile)")

            // Parse output and return a result. 0 exitCode is a match.
            let exitCode = SwiftShell.run(bash: "/usr/bin/grep '\(self.sampleSentinel)' \(self.sampleFile)").exitcode

            if exitCode == 0 {
                callback(.usingCamera); return
            } else if exitCode == 1 {
                callback(.notUsingCamera); return
            } else {
                callback(.errorSampling); return
            }
        }
    }
}

// MARK: Shortcuts provider

struct ShortcutsListProvider {
    func run() async throws -> [String] {
        try await withCheckedThrowingContinuation({ cont in
            DispatchQueue(label: "shortcutsProvider").async {
                let result = SwiftShell.run(bash: "shortcuts list")
                if result.exitcode == 0 {
                    cont.resume(with: .success(result.stdout.split(separator: "\n").map { String($0)} ))
                } else {
                    cont.resume(throwing: ShortcutsError.canNotRetrieve("Could not retrieve shortcuts list"))
                }
            }
        })
    }
}

struct DNDUtil {
    static func enableDND() {
        // On Monterey or newer, we have to use shortcuts. Older we need to do plist trickery.
        if NSAppKitVersion.current.rawValue <= NSAppKitVersion.macOS11_4.rawValue {
            // TODO: Big Sur and older
        } else {
            print(SwiftShell.run(bash: "shortcuts run dndon").exitcode)
        }
    }

    static func disableDND() {
        // On Monterey or newer, we have to use shortcuts. Older we need to do plist trickery.
        if NSAppKitVersion.current.rawValue <= NSAppKitVersion.macOS11_4.rawValue {
            // TODO: Big Sur and older
        } else {
            print(SwiftShell.run(bash: "shortcuts run dndoff"))
        }
    }
}

