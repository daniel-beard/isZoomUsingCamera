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
    @EnvironmentObject var userData: ZoomStatus

    var body: some View {
        VStack {
            Text(userData.textResult)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .onAppear { self.userData.start() }
            HStack {
                Toggle(isOn: $userData.toggleDND) {
                    Text("Automatically enable DND when Zoom video is on")
                }
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ZoomStatus())
    }
}
