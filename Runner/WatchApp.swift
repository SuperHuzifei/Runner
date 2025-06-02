//
//  WatchApp.swift
//  Runner
//
//  Created by 胡云飞 on 2025/6/2.
//

import SwiftUI

@available(iOS 16.0, *)
@available(watchOS 9.0, *)
struct WatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

@available(iOS 16.0, *)
@available(watchOS 9.0, *)
struct WatchContentView: View {
    @State private var remainingTime: Int = 0
    @State private var isRunning: Bool = false
    @State private var currentLap: Int = 1
    @State private var currentLapSeconds: Int = 0
    
    var body: some View {
        VStack(spacing: 15) {
            Text("倒计时")
                .font(.headline)
            
            Text(formatTime(remainingTime))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding()
            
            HStack {
                Text("圈: \(currentLap)")
                    .font(.caption)
                
                Spacer()
                
                Text("秒: \(currentLapSeconds)")
                    .font(.caption)
            }
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button(action: {
                    isRunning.toggle()
                }) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                }
                
                Button(action: {
                    resetTimer()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20))
                }
            }
        }
    }
    
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    func resetTimer() {
        isRunning = false
        remainingTime = 0
        currentLap = 1
        currentLapSeconds = 0
    }
} 