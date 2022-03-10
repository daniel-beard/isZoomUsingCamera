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
    case noResult
    case notScreenSharing
    case screenSharing

    func displayText() -> String {
        switch self {
        case .notScreenSharing: return "Not screen sharing"
        case .screenSharing:    return "Screen sharing"
        default: return ""
        }
    }
}

enum ZoomProcessResult {
    case noResult
    case appRunning
    case appNotRunning
}

enum ShortcutsError: Error {
    case canNotRetrieve(String)
}

enum CustomScriptEvent: String {
    case appStarted =            "~/.iszoomusingcamera/app_started.sh"
    case appEnded =              "~/.iszoomusingcamera/app_ended.sh"
    case cameraEnabled =         "~/.iszoomusingcamera/camera_enabled.sh"
    case cameraDisabled =        "~/.iszoomusingcamera/camera_disabled.sh"
    case screenSharingStarted =  "~/.iszoomusingcamera/screen_sharing_started.sh"
    case screenSharingEnded =    "~/.iszoomusingcamera/screen_sharing_ended.sh"
}

//MARK: Top level observable

final class Model: ObservableObject {

    @AppStorage("dndOnShortcut") var dndOnShortcutSelection = ""
    @AppStorage("dndOffShortcut") var dndOffShortcutSelection = ""
    @AppStorage("shouldToggleDND") var dndToggle = false
    @AppStorage("runCustomScripts") var runCustomScripts = false

    @Published var canShowShortcuts = false

    @Published var textResult: String = "No results" {
        didSet {
            guard dndToggle == true else { return }
            guard oldValue != textResult else { return }

        }
    }
    @Published var screensharingText: String = "Not sharing screen"

    let interval: TimeInterval = 1
    private var timer: Timer? = nil
    private var cameraSampleResult: CameraSampleResult = .noResult {
        didSet {
            guard oldValue != .noResult else { return }
            guard oldValue != .zoomNotRunning else { return }
            guard oldValue != cameraSampleResult else { return }
            switch cameraSampleResult {
                case .usingCamera: enableDND(); runCustomScript(forEvent: .cameraEnabled)
                case .notUsingCamera: disableDND(); runCustomScript(forEvent: .cameraDisabled)
                case .zoomNotRunning: disableDND();
                default: break
            }
        }
    }
    private var screenShareSampleResult: ScreenSharingSampleResult = .noResult {
        didSet {
            guard oldValue != screenShareSampleResult else { return }
            guard oldValue != .noResult else { return }
            switch screenShareSampleResult {
                case .screenSharing: runCustomScript(forEvent: .screenSharingStarted)
                case .notScreenSharing: runCustomScript(forEvent: .screenSharingEnded)
                default: break
            }
        }
    }

    private var zoomProcess: ZoomProcessResult = .noResult {
        didSet {
            guard oldValue != .noResult else { return }
            guard oldValue != zoomProcess else { return }
            switch zoomProcess {
                case .appRunning: runCustomScript(forEvent: .appStarted)
                case .appNotRunning: runCustomScript(forEvent: .appEnded)
                default: break
            }
        }
    }

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
            ZoomProcessProvider().run { result in
                DispatchQueue.main.async {
                    self?.zoomProcess = result
                }
            }
        })
    }

    //MARK: Do not Disturb stuff

    func enableDND() {
        guard dndToggle else { return }
        // On Monterey or newer, we have to use shortcuts. Older we need to do plist trickery.
        if NSAppKitVersion.current.rawValue <= NSAppKitVersion.macOS11_4.rawValue {
            // TODO: Big Sur and older
        } else {
            print(SwiftShell.run(bash: "shortcuts run dndon").exitcode)
        }
    }

    func disableDND() {
        guard dndToggle else { return }
        // On Monterey or newer, we have to use shortcuts. Older we need to do plist trickery.
        if NSAppKitVersion.current.rawValue <= NSAppKitVersion.macOS11_4.rawValue {
            // TODO: Big Sur and older
        } else {
            print(SwiftShell.run(bash: "shortcuts run dndoff"))
        }
    }

    // MARK: Custom scripts

    func runCustomScript(forEvent event: CustomScriptEvent) {
        guard runCustomScripts else { return }
        print("Running custom script: \(event.rawValue)")
        DispatchQueue(label: "CustomScripts").async {
            //TODO: Log outputs to a ~/Library file somewhere
            let result = SwiftShell.run(bash: "bash \(event.rawValue)")
            print("Custom script exitcode: \(result.exitcode)\nstdout: \(result.stdout)\n\(result.stderror)")
        }
    }

    // MARK: Cleanup

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}

// MARK: Zoom providers

struct ZoomProcessProvider {
    func run(callback: @escaping (ZoomProcessResult) -> Void) {
        DispatchQueue(label: "ZoomProcessProvider").async {
            let zoomApps = NSRunningApplication.runningApplications(withBundleIdentifier: "us.zoom.xos")
            guard !zoomApps.isEmpty else {
                callback(.appNotRunning)
                return
            }
            callback(.appRunning)
        }
    }
}

struct ScreenSharingUsageSampleProvider {
    let sampleDuration = 0.1
    let sampleFile = "/tmp/zoomsamplescreensharing"
    let sampleSentinel = "capture thread"

    func run(callback: @escaping (ScreenSharingSampleResult) -> Void) {
        DispatchQueue(label: "ScreenSharingSampler").async {

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
        DispatchQueue(label: "CameraUsageSampler").async {

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
            let grepExitCode = SwiftShell.run(bash: "/usr/bin/grep '\(self.sampleSentinel)' \(self.sampleFile)").exitcode

            if grepExitCode == 0 {
                callback(.usingCamera); return
            } else if grepExitCode == 1 {
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
