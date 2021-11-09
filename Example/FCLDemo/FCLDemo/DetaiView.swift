//
//  DetaiView.swift
//  FCLDemo
//
//  Created by lmcmz on 9/11/21.
//

import SwiftUI

struct DetaiView: View {
    @State var text: String = "Hello ?"

    var body: some View {
        NavigationView {
            List {
                TextEditor(text: $text)
                    .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .disabled(true)
            }
            .navigationTitle("Detail")
        }
    }
}

struct DetaiView_Previews: PreviewProvider {
    static var previews: some View {
        DetaiView()
    }
}
