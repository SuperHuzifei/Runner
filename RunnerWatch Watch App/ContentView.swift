//
//  ContentView.swift
//  RunnerWatch Watch App
//
//  Created by 胡云飞 on 2025/6/24.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    // 使用环境对象替代自己创建的ViewModel
    @EnvironmentObject private var viewModel: TimerViewModel
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
                    HStack(spacing: 20) {
                    // 设置按钮
                    NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                                .font(.system(size: 20))
                    }
                    .disabled(viewModel.isRunning)
                    
                    // 帮助按钮
                    NavigationLink(destination: InfoView()) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 20))
                        }
                        }
                    .padding(.top, 8)
                    
                    // 自动跳圈状态指示
                    HStack {
                        Image(systemName: viewModel.isAutoLapEnabled ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(viewModel.isAutoLapEnabled ? .green : .gray)
                            .font(.caption)
                        
                        Text(viewModel.isAutoLapEnabled ? "自动跳圈: 已开启" : "自动跳圈: 已关闭")
                            .font(.caption2)
                            .foregroundColor(viewModel.isAutoLapEnabled ? .green : .gray)
                }
                    .padding(.top, 10)
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
            .environmentObject(TimerViewModel())
    }
}
