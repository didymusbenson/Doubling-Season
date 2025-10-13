//
//  Token.swift
//  Doubling Season
//
//  Created by DBenson on 6/12/24.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(){
        
            Button(action:{dismiss()}){
                Label("Back", systemImage:"arrowshape.turn.up.backward")
            }
            
            Text("Doubling Season v1.0")
            
            Spacer()
            Text("Thank you for using Doubling Season! I built this app to solve a very specific problem, and it is intended to be free for everyone forever.")
            Text("")
            Text("If you would like to show your appreciation, the best way to support the app is with a fair and honest review in the app store.")
            Text("")
            Text("In the future, a 'tip jar' in-app-purchase will be made available for you to that will allow you to directly support continued development of Doubling Season.")
            Text("")
            Text("My commitment to you is that is to keep this app ad-free forever. ")
            Spacer()
            
            
        }.frame(maxWidth:UIScreen.main.bounds.width * 0.80)
        
    }
}


#Preview {
    AboutView()
    
}
