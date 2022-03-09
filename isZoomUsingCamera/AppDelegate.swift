//
//  AppDelegate.swift
//  isZoomUsingCamera
//
//  Created by Daniel Beard on 3/27/20.
//  Copyright © 2020 dbeard. All rights reserved.
//

import Cocoa
import SwiftUI

let DEFAULTS_WINDOW_VISIBLE_BY_DEFAULT = "mainWindow.Visible.By.Default.v1"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var window: NSWindow!
    var hideWindowItem: NSMenuItem!
    var statusBarItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Creating the application menu
        createStatusBarMenu()

//        if UserDefaults.standard.object(forKey: DEFAULTS_WINDOW_VISIBLE_BY_DEFAULT) as? NSControl.StateValue == .off {
            createAndShowWindow()
//        }
    }

    // MARK: UI Creation
    
    /// Creates the Status Bar Menu for the application and sets all the menu elements
    func createStatusBarMenu() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.title = "🤐"
        let statusBarMenu = NSMenu(title: "Zoom Camera and Notifications")
        statusBarItem.menu = statusBarMenu
        
        hideWindowItem = NSMenuItem(title: "Hide main window",
                                        action: #selector(toggleHideWindow),
                                        keyEquivalent: "")
        let hideWindowState = UserDefaults.standard.object(forKey: DEFAULTS_WINDOW_VISIBLE_BY_DEFAULT) as? NSControl.StateValue ?? .off
        hideWindowItem.state = hideWindowState
        statusBarMenu.addItem(hideWindowItem)
        
        let hideByDefaultItem = NSMenuItem(title: "Hide main window at launch",
                                           action: #selector(toggleHideWindowAtLaunch),
                                           keyEquivalent: "")
        hideByDefaultItem.state = hideWindowState
        statusBarMenu.addItem(hideByDefaultItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(terminate), keyEquivalent: "")
        quitItem.isEnabled = true
        statusBarMenu.addItem(quitItem)
    }
        
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
        toggleHideWindow()
        return false
    }
    
    // MARK: Main window managment actions
    
    /// This is the action that gets executed when the user clicks on the red cross or the menu item
    /// It will hide the main window on unhide based on the previous state
    @objc func toggleHideWindow() {
        switch hideWindowItem.state {
        case .off:
            NSApp.hide(nil)
            hideWindowItem.state = .on
        
        case .on:
            NSApp.unhide(nil)
            if window == nil { createAndShowWindow() }
            hideWindowItem.state = .off
            
        default:
            print("Do nothing")
        }
    }
    
    /// Saves into the UserDefault if the user wants the main window to be hidden or not by default
    /// when the user opens the app
    /// - Parameter sender: The Menu Item that toggled this function. We will take the new configuration from the menu item
    @objc func toggleHideWindowAtLaunch(_ sender: NSMenuItem) {
        sender.state = sender.state == .off ? .on : .off
        UserDefaults.standard.set(sender.state, forKey: DEFAULTS_WINDOW_VISIBLE_BY_DEFAULT)
        UserDefaults.standard.synchronize()
    }

}
