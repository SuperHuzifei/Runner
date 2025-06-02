//
//  ContentView.swift
//  Runner
//
//  Created by 胡云飞 on 2025/6/2.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                
                TimerView()
                    .tag(1)
                
                DistanceView()
                    .tag(2)
                
                SettingsView()
                    .tag(3)
            }
            .edgesIgnoringSafeArea(.bottom)
            
            HStack {
                Spacer()
                
                TabBarButton(iconName: "house.fill", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                Spacer()
                
                TabBarButton(iconName: "timer", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                Spacer()
                
                TabBarButton(iconName: "map", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                
                Spacer()
                
                TabBarButton(iconName: "gearshape.fill", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 0)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }
}

struct TabBarButton: View {
    let iconName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding(.vertical, 8)
            .frame(width: 60)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
