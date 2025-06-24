//
//  ContentView.swift
//  RunnerWatch Watch App
//
//  Created by 胡云飞 on 2025/6/24.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @State private var remainingTime: Int = 0
    @State private var isRunning: Bool = false
    @State private var currentLap: Int = 0
    @State private var currentLapSeconds: Int = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    Text("倒计时")
                        .font(.headline)
                    
                    Text(formatTime(viewModel.remainingTime))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                    
                    HStack {
                        Text("圈: \(viewModel.currentLap + 1)/\(viewModel.totalLaps())")
                            .font(.caption)
                        
                        Spacer()
                        
                        if viewModel.isCountingUp {
                            // 显示正向计时
                            Text("超时: +\(viewModel.countUpSeconds)秒")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            // 显示倒计时
                            Text("圈内: \(viewModel.currentLapRemainingSeconds)秒")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 完成当前圈按钮
                    if viewModel.isRunning && !viewModel.isInExtraTime && !viewModel.isTimerCompleted {
                        Button(action: {
                            viewModel.saveCurrentLapRemainingTime()
                        }) {
                            Text(viewModel.isCountingUp ? "完成本圈" : "完成本圈")
                                .font(.caption)
                        }
                        .tint(viewModel.isCountingUp ? .red : .blue)
                        .padding(.vertical, 5)
                    }
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            if viewModel.isRunning {
                                viewModel.pauseTimer()
                            } else {
                                viewModel.startTimer()
                            }
                        }) {
                            Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                        }
                        .disabled(viewModel.isTimerCompleted)
                        
                        Button(action: {
                            viewModel.resetTimer()
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                        }
                    }
                    
                    // 底部导航按钮
                    HStack(spacing: 15) {
                        // 设置按钮
                        NavigationLink(destination: SettingsView()) {
                            HStack {
                                Image(systemName: "gear")
                                    .font(.system(size: 14))
                                Text("设置")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isRunning)
                        
                        // 帮助按钮
                        NavigationLink(destination: InfoView()) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                Text("帮助")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
    }
    
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
