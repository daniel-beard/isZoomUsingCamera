//
//  SampleProvider.swift
//  isZoomUsingCamera
//
//  Created by Daniel Beard on 3/27/20.
//  Copyright © 2020 dbeard. All rights reserved.
//

import AppKit
import SwiftUI
import Combine
import SwiftShell

let DEFAULTS_ENABLE_DND_AUTOMATICALLY = "enable.dnd.auntomatically.v1"

final class ZoomStatus: ObservableObject {
    @Published var textResult: String = "No results" {
        didSet {
            guard toggleDND == true else { return }
            guard oldValue != textResult else { return }
            switch cameraSampleResult {
                case .usingCamera: DNDUtil.enableDND()
                case .notUsingCamera, .zoomNotRunning: DNDUtil.disableDND()
                default: break
            }
        }
    }
    @Published var screensharingText: String = "Not sharing screen"
    @Published var toggleDND = UserDefaults.standard.bool(forKey: DEFAULTS_ENABLE_DND_AUTOMATICALLY) {
        didSet {
            UserDefaults.standard.set(toggleDND, forKey: DEFAULTS_ENABLE_DND_AUTOMATICALLY)
            UserDefaults.standard.synchronize()
        }
    }
    
    let interval: TimeInterval = 1
    private var timer: Timer? = nil
    private var cameraSampleResult: CameraSampleResult = .noResult
    private var screenShareSampleResult: ScreenSharingSampleResult = .notScreenSharing

    func start() {
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

struct DNDUtil {
    static func enableDND() {
        print(SwiftShell.run(bash: "defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb -boolean true").exitcode)
        print(SwiftShell.run(bash: #"defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturbDate -date "`date -u +\"%Y-%m-%d %H:%M:%S +0000\"`""#).exitcode)
        print(SwiftShell.run(bash: "killall NotificationCenter").exitcode)
    }

    static func disableDND() {
        SwiftShell.run(bash: "defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb -boolean false")
        SwiftShell.run(bash: "killall NotificationCenter")
    }
}

