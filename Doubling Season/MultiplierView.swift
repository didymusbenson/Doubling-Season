//
//  MultiplierView.swift
//  Doubling Season
//
//  Created on 10/13/25.
//

import SwiftUI

struct MultiplierView: View {
    @AppStorage("tokenMultiplier") private var multiplier: Int = 1
    @State private var showControls = false
    @State private var showManualInput = false
    @State private var manualInputValue = ""
    
    var body: some View {
        VStack {
            if showControls {
                HStack(spacing: 16) {
                    Button(action: {
                        if multiplier > 1 {
                            multiplier = max(1, multiplier / 2)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(multiplier <= 1)
                    
                    Text("x\(multiplier)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(minWidth: 60)
                        .onLongPressGesture {
                            manualInputValue = String(multiplier)
                            showManualInput = true
                        }
                    
                    Button(action: {
                        multiplier = min(1024, multiplier * 2) // Cap at reasonable limit
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("x\(multiplier)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                    }
                    .onLongPressGesture {
                        manualInputValue = String(multiplier)
                        showManualInput = true
                    }
            }
        }
        .onTapGesture {
            if showControls {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = false
                }
            }
        }
        .alert("Set Multiplier", isPresented: $showManualInput) {
            TextField("Multiplier", text: $manualInputValue)
                .keyboardType(.numberPad)
            Button("Set") {
                if let value = Int(manualInputValue), value >= 1 {
                    multiplier = min(1024, value) // Cap at reasonable limit
                }
                manualInputValue = ""
            }
            Button("Cancel", role: .cancel) {
                manualInputValue = ""
            }
        } message: {
            Text("Enter a multiplier value (minimum 1)")
        }
    }
}

#Preview {
    MultiplierView()
}