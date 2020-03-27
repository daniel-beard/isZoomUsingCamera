//
//  SampleProvider.swift
//  isZoomUsingCamera
//
//  Created by Daniel Beard on 3/27/20.
//  Copyright © 2020 dbeard. All rights reserved.
//

import AppKit
import Combine
import SwiftShell

final class ZoomStatus: ObservableObject {
    @Published var textResult = "No results"
    let interval: TimeInterval = 1
    private var timer: Timer? = nil

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { [weak self] _ in
            let sampler = SampleProvider()
            sampler.run(callback: { result in
                DispatchQueue.main.async {
                    switch result {
                        case .noResult:         self?.textResult = "No result"
                        case .usingCamera:      self?.textResult = "Zoom is USING the camera"
                        case .notUsingCamera:   self?.textResult = "Zoom is NOT USING the camera"
                        case .zoomNotRunning:   self?.textResult = "Zoom does not appear to be running"
                        case .errorSampling:    self?.textResult = "Error sampling"
                    }
                }
            })
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

enum SampleResult {
    case noResult
    case usingCamera
    case zoomNotRunning
    case notUsingCamera
    case errorSampling
}

struct SampleProvider {

    let sampleDuration = 0.1
    let sampleFile = "/tmp/zoomsample"
    let sampleSentinel = "CMIOGraph::DoWork"

    func run(callback: @escaping (SampleResult) -> Void) {
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
            try? SwiftShell.runAndPrint(bash: "/usr/bin/sample \(pid) \(self.sampleDuration) -f \(self.sampleFile)")

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

