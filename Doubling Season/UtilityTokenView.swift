//
//  Token.swift
//  Doubling Season
//
//  Created by DBenson on 6/12/24.
//

import SwiftUI

struct UtilityTokenView: View {
    
    @State var item: Item
    @State private var isShowingRemoveAlert = false
    @State private var isShowingAddAlert = false
    @State private var isShowingUntapAlert = false
    @State private var isShowingTapAlert = false
    @State private var tempAlertValue = ""
    
    var body: some View {
        
 
            
            VStack {
                Text(item.name).font(.title)
                
                // Top Row - Name, Color, Tapped/Untapped
                HStack {
                    Text(Image(systemName:"rectangle.portrait.bottomhalf.inset.filled"))
                    Text(String(item.amount - item.tapped)).font(.title2)
                    Text(Image(systemName:"rectangle.landscape.rotate"))
                    Text(String(item.tapped)).font(.title2)
                }
                
                HStack{
                    Spacer()
                    // subtract
                    Button(action:{}){
                        Text(Image(systemName:"minus")).font(.title2)
                    }.buttonStyle(BorderlessButtonStyle())
                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                        isShowingRemoveAlert = true
                    })
                    .simultaneousGesture(TapGesture().onEnded {
                        if(item.amount > 0){
                            if (item.amount - item.tapped <= 0){
                                item.tapped -= 1
                            }
                            item.amount -= 1
                        }
                    })
                    Spacer()
                    // add
                    Button(action:{}){
                        Text(Image(systemName:"plus")).font(.title2)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                        isShowingAddAlert = true
                    })
                    .simultaneousGesture(TapGesture().onEnded {
                            item.amount += 1
                    })
                    Spacer()
                }
                // Bottom Row - buttons, Power/Toughness
                HStack {
 
                    Spacer()
                    // untap
                    Button(action:{
                    }){
                        Text(Image(systemName:"arrow.counterclockwise.circle")).font(.title2)
                    }.buttonStyle(BorderlessButtonStyle())
                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                        isShowingUntapAlert = true
                    })
                    .simultaneousGesture(TapGesture().onEnded {
                        if(item.tapped > 0){
                            item.tapped -= 1
                        }
                        
                    })
                    Spacer()
                    // tap
                    Button(action:{
                        
                    }){
                        Text(Image(systemName:"arrow.clockwise.circle")).font(.title2)
                    }.buttonStyle(BorderlessButtonStyle())
                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                        isShowingTapAlert = true
                    })
                    .simultaneousGesture(TapGesture().onEnded {
                        if(item.tapped < item.amount){
                            item.tapped += 1
                        }
                    })
                    Spacer()
                }
                .alert("Add Tokens", isPresented: $isShowingAddAlert){
                    TextField("Value", text: $tempAlertValue)
                    Button("Submit"){
                        let n: Int? = Int(tempAlertValue)
                      //  if(n ?? 0 < 0){
                       //     n = 0
                       // }
                        item.amount += n ?? 0
                        tempAlertValue = ""
                    }
                }message:{
                    Text("How many \(item.name)?")
                }
                .alert("Remove Tokens", isPresented: $isShowingRemoveAlert){
                    TextField("Value", text: $tempAlertValue)
                    Button("Remove"){
                        var n: Int? = Int(tempAlertValue)
                    //    if(n ?? 0 < 0){
                     //       n = 0
                     //   }
                        if(n ?? 0 > item.amount){
                            n = item.amount
                        }
                        item.amount -= n ?? 0
                        tempAlertValue = ""
                    }
                    Button("Reset", role: .destructive){
                        item.amount = 0
                        item.tapped = 0
                    }
                }message:{
                    Text("Remove tokens \(item.name)?")
                }
                .alert("Untap", isPresented: $isShowingUntapAlert){
                    TextField("Value", text: $tempAlertValue)
                    Button("Untap"){
                        var n: Int? = Int(tempAlertValue)
                      //  if(n ?? 0 < 0){
                      //      n = 0
                      //  }
                        if(n ?? 0 > item.tapped){
                            n = item.tapped
                        }
                        item.tapped -= n ?? 0
                        tempAlertValue = ""
                    }
                }message:{
                    Text("Untap tokens \(item.name)?")
                }
                .alert("Tap Tokens", isPresented: $isShowingTapAlert){
                    TextField("Value", text: $tempAlertValue)
                    Button("Tap"){
                        let n: Int? = Int(tempAlertValue)
                     //   if(n ?? 0 < 0){
                     //       n = 0
                     //   }
                        if(n ?? 0 > item.amount - item.tapped){
                            item.tapped = item.amount
                        }
                        else{
                            item.tapped += n ?? 0
                        }
                        tempAlertValue = ""
                    }
                }message:{
                    Text("How many \(item.name)?")
                }
                
            }.padding(10).background(Color(UIColor.secondarySystemGroupedBackground)).frame(width: UIScreen.main.bounds.width * 0.33 - 5).cornerRadius(10)
        
    }

}



#Preview {
    UtilityTokenView(item: Item(abilities:"Tap and sac to get mana", name: "Treasure", pt: "", colors:"WUBRG", amount: 1, createTapped: false))
    
}
