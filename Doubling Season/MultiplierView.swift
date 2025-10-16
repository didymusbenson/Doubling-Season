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
        HStack {
            if showControls {
                // Expanded pill shape with controls
                HStack(spacing: 16) {
                    Button(action: {
                        if multiplier > 1 {
                            multiplier = max(1, multiplier - 1)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(multiplier <= 1)
                    
                    Text("x\(multiplier)")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(minWidth: 80)
                        .onLongPressGesture {
                            manualInputValue = String(multiplier)
                            showManualInput = true
                        }
                    
                    Button(action: {
                        multiplier = min(1024, multiplier + 1) // Cap at reasonable limit
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            } else {
                // Collapsed circular badge
                Text("x\(multiplier)")
                    .font(.largeTitle) // About twice the size of .title2
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .frame(width: 80, height: 80)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showControls.toggle()
                        }
                    }
                    .onLongPressGesture {
                        manualInputValue = String(multiplier)
                        showManualInput = true
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .onTapGesture {
            if showControls {
                withAnimation(.easeInOut(duration: 0.3)) {
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
