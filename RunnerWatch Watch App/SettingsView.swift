import SwiftUI
import AVFoundation

// 创建一个自定义的TextField样式，适用于watchOS
struct WatchTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .padding(.vertical, 2)
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = TimerViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var speechRate: Float = 0.5
    @State private var totalDistanceText: String = "1000"
    @State private var lapDistanceText: String = "200"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // 总时间设置
                Group {
                    Text("总时间")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        Picker("分钟", selection: $viewModel.totalMinutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .labelsHidden()
                        
                        Text("分")
                            .font(.caption2)
                        
                        Picker("秒钟", selection: $viewModel.totalSeconds) {
                            ForEach(0..<60) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .labelsHidden()
                        
                        Text("秒")
                            .font(.caption2)
                    }
                }
                
                Divider()
                
                // 距离设置
                Group {
                    Text("总距离")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        TextField("总距离", text: $totalDistanceText)
                            .textFieldStyle(WatchTextFieldStyle())
                            .onAppear {
                                totalDistanceText = "\(viewModel.totalDistance)"
                            }
                            .onChange(of: totalDistanceText) { newValue in
                                if let intValue = Int(newValue) {
                                    viewModel.totalDistance = intValue
                                }
                            }
                        
                        Text("米")
                            .font(.caption2)
                    }
                    .padding(.vertical, 5)
                    
                    Text("每圈距离")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        TextField("每圈距离", text: $lapDistanceText)
                            .textFieldStyle(WatchTextFieldStyle())
                            .onAppear {
                                lapDistanceText = "\(viewModel.lapDistance)"
                            }
                            .onChange(of: lapDistanceText) { newValue in
                                if let intValue = Int(newValue) {
                                    viewModel.lapDistance = intValue
                                }
                            }
                        
                        Text("米")
                            .font(.caption2)
                    }
                }
                
                Divider()
                
                // 语音设置
                Group {
                    Text("语音设置")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        Text("语速:")
                            .font(.caption)
                        
                        Slider(value: $speechRate, in: 0.1...1.0, step: 0.1)
                            .onChange(of: speechRate) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "speechRate")
                            }
                    }
                    
                    Button("测试语音") {
                        testVoice()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical, 5)
                }
                
                Divider()
                
                // 保存按钮
                Button("保存设置") {
                    saveSettings()
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 10)
            }
            .padding()
        }
        .navigationTitle("设置")
        .onAppear {
            // 加载当前语速
            self.speechRate = UserDefaults.standard.float(forKey: "speechRate")
            if self.speechRate == 0 {
                self.speechRate = 0.5 // 默认值
            }
            
            // 初始化距离文本
            totalDistanceText = "\(viewModel.totalDistance)"
            lapDistanceText = "\(viewModel.lapDistance)"
        }
    }
    
    private func saveSettings() {
        // 保存设置到UserDefaults
        UserDefaults.standard.set(viewModel.totalMinutes, forKey: "totalMinutes")
        UserDefaults.standard.set(viewModel.totalSeconds, forKey: "totalSeconds")
        
        // 确保文本值正确转换为整数
        if let totalDist = Int(totalDistanceText) {
            UserDefaults.standard.set(totalDist, forKey: "totalDistance")
        }
        
        if let lapDist = Int(lapDistanceText) {
            UserDefaults.standard.set(lapDist, forKey: "lapDistance")
        }
        
        UserDefaults.standard.set(speechRate, forKey: "speechRate")
    }
    
    private func testVoice() {
        let utterance = AVSpeechUtterance(string: "这是一个语音测试")
        
        let languageCode = "zh-CN"
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = speechRate
        utterance.volume = 1.0
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 