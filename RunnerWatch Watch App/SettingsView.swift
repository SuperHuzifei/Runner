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
    // 使用环境对象替代自己创建的ViewModel
    @EnvironmentObject private var viewModel: TimerViewModel
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
                        .onChange(of: viewModel.totalMinutes) { newValue in
                            // 实时保存分钟设置
                            UserDefaults.standard.set(newValue, forKey: "totalMinutes")
                        }
                        
                        Text("分")
                            .font(.caption2)
                        
                        Picker("秒钟", selection: $viewModel.totalSeconds) {
                            ForEach(0..<60) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: viewModel.totalSeconds) { newValue in
                            // 实时保存秒钟设置
                            UserDefaults.standard.set(newValue, forKey: "totalSeconds")
                        }
                        
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
                                    // 实时保存总距离
                                    UserDefaults.standard.set(intValue, forKey: "totalDistance")
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
                                    // 实时保存每圈距离
                                    UserDefaults.standard.set(intValue, forKey: "lapDistance")
                                }
                            }
                        
                        Text("米")
                            .font(.caption2)
                    }
                }
                
                Divider()
                
                // 自动跳圈设置
                Group {
                    Text("圈数设置")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Toggle("自动跳圈", isOn: $viewModel.isAutoLapEnabled)
                        .onChange(of: viewModel.isAutoLapEnabled) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "isAutoLapEnabled")
                        }
                    
                    Text("开启后每圈结束时将自动进入下一圈")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
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
                
                // 返回按钮
                Button("返回") {
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
            .environmentObject(TimerViewModel())
    }
} 