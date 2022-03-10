//
//  AppDelegate.swift
//  isZoomUsingCamera
//
//  Created by Daniel Beard on 3/27/20.
//  Copyright © 2020 dbeard. All rights reserved.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var window: NSWindow!
    var hideWindowItem: NSMenuItem!
    var statusBarItem: NSStatusItem!

    @AppStorage("hideWindowOnLaunch") var hideWindowOnLaunch = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Creating the application menu
        createStatusBarMenu()

        if hideWindowOnLaunch == false {
            createAndShowWindow()
        }
    }

    // MARK: UI Creation

    @objc func statusBarButtonClicked(sender: NSStatusBarButton)  {
        let event = NSApp.currentEvent!
        if event.type == .leftMouseUp {
            showMainWindow()
        }
    }
    
    /// Creates the Status Bar Menu for the application and sets all the menu elements
    func createStatusBarMenu() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.title = "🤐"
        statusBarItem.button?.action = #selector(self.statusBarButtonClicked(sender:))
    }

    //TODO: Add option for floating window?
    /// Creates the main window of the application and makes it visible.
    func createAndShowWindow() {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView().environmentObject(Model())
        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        window.delegate = self
    }

    /// Quits the application
    @objc func terminate() {
        NSRunningApplication.current.terminate()
    }

    // MARK: Window Delegate
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // We do this here so the application is not closed when the user clicks on the red cross
        hideMainWindow()
        return false
    }
    
    // MARK: Main window managment actions

    func showMainWindow() {
        NSApp.unhide(nil)
        if window == nil { createAndShowWindow() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideMainWindow() {
        NSApp.hide(nil)
    }
}
