//
//  ContentView.swift
//  isZoomUsingCamera
//
//  Created by Daniel Beard on 3/27/20.
//  Copyright © 2020 dbeard. All rights reserved.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var model: Model
    @State private var showingPrefs = false

    var body: some View {
        // Top VStack
        VStack  {
            // Image header
            VStack {
                if showingPrefs {
                    Image("Settings_Icon")
                        .resizable()
                        .frame(width: 70, height: 70)
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image("Settings_Icon")
                        .aspectRatio(contentMode: .fit)
                }
            }.animation(.easeInOut, value: showingPrefs)
            if !showingPrefs {
                Text(model.textResult)
                    .frame(maxWidth: .infinity, maxHeight: 100)
                    .onAppear { self.model.start() }
                    .animation(.easeInOut, value: showingPrefs)
                Text(model.screensharingText)
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .animation(.easeInOut, value: showingPrefs)
            }
            VStack {
                VStack {
                    HStack {
                        Toggle(isOn: $showingPrefs) {
                            Text("Preferences")
                                .font(showingPrefs ? .largeTitle : .subheadline)
                        }.toggleStyle(.switch)
                    }
                }
                if showingPrefs == true {
                    PrefsView()
                }
            }.padding([.all]).animation(.easeInOut, value: showingPrefs)
        }.padding([.all])
    }
}

struct PrefsView: View {
    @EnvironmentObject var model: Model
    var body: some View {
        VStack {
            Form {
                Section {
                    Toggle(isOn: $model.dndToggle) {
                        Text("Automatically enable DND when Zoom video is on")
                    }
                    if model.canShowShortcuts {
                        Picker(selection: $model.dndOnShortcutSelection, label:
                            Text("DND on shortcut")
                            , content: {
                            ForEach(model.listOfAvailableShortcuts, id: \.self) { val in
                                Text(val)
                            }
                        })
                        Picker(selection: $model.dndOffShortcutSelection, label:
                            Text("DND off shortcut")
                            , content: {
                            ForEach(model.listOfAvailableShortcuts, id: \.self) { val in
                                Text(val)
                            }
                        })
                    }
                    Toggle(isOn: $model.runCustomScripts) {
                        Text("Run custom scripts in ~/.iszoomusingcamera")
                    }
                    Spacer()
                    Button {
                        exit(0)
                    } label: {
                        Text("Quit the App")
                    }
                }
            }

        }.padding([.all])
    }
}

struct PrefsView_Previews: PreviewProvider {
    static var previews: some View {
        PrefsView().environmentObject(Model())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(Model())
    }
}
