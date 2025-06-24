import SwiftUI

struct InfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("使用帮助")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 5)
                
                Group {
                    Text("计时器操作")
                        .font(.subheadline)
                        .bold()
                    
                    Text("• 开始/暂停: 点击播放/暂停按钮")
                        .font(.caption2)
                    
                    Text("• 重置: 点击循环箭头按钮")
                        .font(.caption2)
                    
                    Text("• 完成当前圈: 运行时点击\"完成本圈\"按钮")
                        .font(.caption2)
                }
                .padding(.bottom, 5)
                
                Group {
                    Text("额外时间")
                        .font(.subheadline)
                        .bold()
                    
                    Text("• 每圈提前完成会积累额外时间")
                        .font(.caption2)
                    
                    Text("• 最后一圈会使用累积的额外时间")
                        .font(.caption2)
                    
                    Text("• 超时完成会减少额外时间")
                        .font(.caption2)
                }
                .padding(.bottom, 5)
                
                Group {
                    Text("设置功能")
                        .font(.subheadline)
                        .bold()
                    
                    Text("• 总时间: 设置训练总时长")
                        .font(.caption2)
                    
                    Text("• 总距离: 设置训练总距离(米)")
                        .font(.caption2)
                    
                    Text("• 每圈距离: 设置每圈距离(米)")
                        .font(.caption2)
                    
                    Text("• 语音设置: 调整语音播报速度")
                        .font(.caption2)
                }
                
                Text("版本: 1.0.0")
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
            .padding()
        }
        .navigationTitle("关于")
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView()
    }
} 