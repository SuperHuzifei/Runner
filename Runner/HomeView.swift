//
//  HomeView.swift
//  Runner
//
//  Created by 胡云飞 on 2025/6/2.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 70))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                Text("倒计时语音读秒器")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "timer", title: "计时功能", description: "设置总时间和每圈距离，自动计算目标时间")
                    FeatureRow(icon: "waveform", title: "语音播报", description: "每秒语音播报当前圈内秒数")
                    FeatureRow(icon: "location", title: "距离测量", description: "使用定位功能辅助判断圈数")
                    if #available(iOS 16.0, *) {
                        FeatureRow(icon: "applewatch", title: "Apple Watch支持", description: "在手表上查看和控制倒计时")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("主页")
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
} 