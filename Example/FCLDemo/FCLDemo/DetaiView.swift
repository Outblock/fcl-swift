//
//  DetaiView.swift
//  FCLDemo
//
//  Created by lmcmz on 9/11/21.
//

import SwiftUI

struct DetaiView: View {
    @State var text: String = """

    Hello ?

    """

    var body: some View {
        NavigationView {
            List {
                ZStack {
                    TextEditor(text: $text)
                        .padding(.all, 8)
                        .disabled(true)

                    Text(text).opacity(0).padding(.all, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Detail")
        }
    }
}

struct DetaiView_Previews: PreviewProvider {
    static var previews: some View {
        DetaiView()
    }
}
