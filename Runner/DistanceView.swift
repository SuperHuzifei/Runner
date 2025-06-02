//
//  DistanceView.swift
//  Runner
//
//  Created by 胡云飞 on 2025/6/2.
//

import SwiftUI
import MapKit
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var isTracking = false
    @Published var totalDistance: Double = 0
    @Published var currentLapDistance: Double = 0
    @Published var lapCount: Int = 0
    @Published var lapDistance: Double = 200
    
    private var previousLocation: CLLocation?
    private var locationHistory: [CLLocation] = []
    
    override init() {
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        isTracking = true
        totalDistance = 0
        currentLapDistance = 0
        lapCount = 0
        locationHistory.removeAll()
        previousLocation = nil
        
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }
    
    func resetTracking() {
        stopTracking()
        totalDistance = 0
        currentLapDistance = 0
        lapCount = 0
        locationHistory.removeAll()
        previousLocation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 更新位置
        self.location = location
        
        // 更新地图区域
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        // 计算距离
        if let previousLocation = previousLocation {
            let distanceInMeters = location.distance(from: previousLocation)
            
            // 只有当距离变化超过1米时才计算
            if distanceInMeters > 1 {
                totalDistance += distanceInMeters
                currentLapDistance += distanceInMeters
                
                // 检查是否完成一圈
                if currentLapDistance >= lapDistance {
                    lapCount += 1
                    currentLapDistance -= lapDistance
                }
            }
        }
        
        // 保存历史位置
        locationHistory.append(location)
        self.previousLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 处理授权变化
    }
}

struct DistanceView: View {
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    // 地图
                    Map(coordinateRegion: $locationManager.region, showsUserLocation: true)
                        .frame(height: 250)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    // 距离信息
                    VStack(spacing: 20) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("总距离")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f 米", locationManager.totalDistance))
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("当前圈")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("\(locationManager.lapCount + 1)")
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("圈距离")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    TextField("圈距离", value: $locationManager.lapDistance, formatter: NumberFormatter())
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 80)
                                    
                                    Text("米")
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("当前圈距离")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f 米", locationManager.currentLapDistance))
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        // 进度条
                        VStack(alignment: .leading) {
                            Text("当前圈进度")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .frame(width: geometry.size.width, height: 20)
                                        .opacity(0.3)
                                        .foregroundColor(.gray)
                                    
                                    Rectangle()
                                        .frame(width: min(CGFloat(locationManager.currentLapDistance / locationManager.lapDistance) * geometry.size.width, geometry.size.width), height: 20)
                                        .foregroundColor(.blue)
                                }
                                .cornerRadius(10)
                            }
                            .frame(height: 20)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                    
                    // 控制按钮
                    HStack(spacing: 20) {
                        Button(action: {
                            if locationManager.isTracking {
                                locationManager.stopTracking()
                            } else {
                                locationManager.startTracking()
                            }
                        }) {
                            Text(locationManager.isTracking ? "停止" : "开始")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 100, height: 50)
                                .background(locationManager.isTracking ? Color.red : Color.green)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            locationManager.resetTracking()
                        }) {
                            Text("重置")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 100, height: 50)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.vertical)
                }
                .padding(.vertical)
            }
            .navigationTitle("测距")
            .edgesIgnoringSafeArea(.top)
        }
    }
}

struct DistanceView_Previews: PreviewProvider {
    static var previews: some View {
        DistanceView()
    }
} 