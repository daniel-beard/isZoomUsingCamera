//
//  ContentView.swift
//  isZoomUsingCamera
//
//  Created by Daniel Beard on 3/27/20.
//  Copyright © 2020 dbeard. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var zoomStatus = ZoomStatus()

    var body: some View {
        VStack {
            Text("\(zoomStatus.textResult)")
                .frame(maxWidth: .infinity, maxHeight: 300)
                .onAppear { self.zoomStatus.start() }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
