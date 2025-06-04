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
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var isLocationAuthorized = false
    @Published var hasInitialLocation = false
    @Published var trackingAccuracy: String = "未知"
    @Published var currentSpeed: Double = 0.0
    @Published var isLocationLocked = false
    @Published var locationStatus: String = "等待定位..."
    @Published var enableCoordinateCorrection: Bool = true // 默认开启坐标校正
    @Published var latitudeOffset: Double = 0.00005 // 默认纬度偏移值
    @Published var longitudeOffset: Double = 0.00005 // 默认经度偏移值
    @Published var locationHistory: [CLLocation] = [] // 原始位置历史
    @Published var showTrackDebugControls: Bool = false // 显示轨迹调试控制
    @Published var needsInitialZoom: Bool = true // 用于标记是否需要初始缩放
    
    private var previousLocation: CLLocation?
    private var trackingStartTime: Date?
    private var isFirstLocationUpdate = true
    
    override init() {
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 1 // 每移动1米更新一次位置
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        
        // 检查当前授权状态
        checkLocationAuthorization()
    }
    
    private func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationAuthorized = true
            startLocationUpdates()
        case .notDetermined:
        locationManager.requestWhenInUseAuthorization()
        default:
            isLocationAuthorized = false
            locationStatus = "需要位置权限"
        }
    }
    
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
        locationStatus = "正在获取位置..."
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startTracking() {
        isTracking = true
        totalDistance = 0
        currentLapDistance = 0
        lapCount = 0
        locationHistory.removeAll()
        routeCoordinates.removeAll()
        previousLocation = nil
        trackingStartTime = Date()
        
        // 确保后台更新已启用
        locationManager.allowsBackgroundLocationUpdates = true
        startLocationUpdates()
        
        // 自动开启位置锁定，但不改变缩放级别
        isLocationLocked = true
        
        // 如果没有设置初始区域，设置一个合理的默认值
        if region.span.latitudeDelta > 0.05 {
            // 初始区域太大，设置一个更合适的默认值
            region.span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        }
    }
    
    func stopTracking() {
        isTracking = false
        trackingStartTime = nil
        // 不停止位置更新，仅停止跟踪
    }
    
    func resetTracking() {
        stopTracking()
        totalDistance = 0
        currentLapDistance = 0
        lapCount = 0
        locationHistory.removeAll()
        routeCoordinates.removeAll()
        previousLocation = nil
        currentSpeed = 0.0
    }
    
    func toggleLocationLock() {
        isLocationLocked.toggle()
        
        // 如果开启了位置锁定，且已有位置信息，则立即居中显示
        if isLocationLocked, let location = location {
            centerMapOnUserLocation(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 更新位置状态
        locationStatus = "已定位"
        
        // 更新位置
        self.location = location
        
        // 更新精度信息
        updateAccuracyInfo(location)
        
        // 更新速度
        if location.speed > 0 {
            currentSpeed = location.speed
        }
        
        // 如果是第一次获取位置，自动缩放到用户位置并设置合适的缩放级别
        if isFirstLocationUpdate {
            // 设置一个合适的初始缩放级别
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            isFirstLocationUpdate = false
            hasInitialLocation = true
            needsInitialZoom = true // 标记需要初始缩放
        } else if isLocationLocked {
            // 位置锁定时，保持当前缩放级别，只更新中心点
            centerMapOnUserLocation(location)
        }
        
        // 如果正在跟踪，则记录轨迹
        if isTracking {
            // 原始坐标，用于日志输出
            let originalCoordinate = location.coordinate
            
            // 计算距离
            if let previousLocation = previousLocation {
                let distanceInMeters = location.distance(from: previousLocation)
                totalDistance += distanceInMeters
                currentLapDistance += distanceInMeters
                
                // 检查是否完成一圈
                if currentLapDistance >= lapDistance {
                    lapCount += 1
                    currentLapDistance -= lapDistance
                }
            }
            
            // 保存历史位置 - 无需校正，直接使用原始位置
            locationHistory.append(location)
            
            // 输出调试信息
            if enableCoordinateCorrection {
                let correctedCoordinate = correctCoordinate(originalCoordinate)
                logCoordinateInfo(originalCoordinate, correctedCoordinate)
            }
        }
        
        self.previousLocation = location
    }
    
    func updateAccuracyInfo(_ location: CLLocation) {
        let accuracy = location.horizontalAccuracy
        
        if accuracy <= 5 {
            trackingAccuracy = "高精度 (±\(Int(accuracy))米)"
        } else if accuracy <= 10 {
            trackingAccuracy = "中等精度 (±\(Int(accuracy))米)"
        } else if accuracy <= 20 {
            trackingAccuracy = "低精度 (±\(Int(accuracy))米)"
        } else {
            trackingAccuracy = "不可靠 (±\(Int(accuracy))米)"
        }
    }
    
    func centerMapOnUserLocation(_ location: CLLocation) {
        // 保持当前的缩放级别不变，只更改中心点
        let currentSpan = region.span
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: currentSpan // 保持当前缩放级别
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        locationStatus = "定位失败: \(error.localizedDescription)"
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            isLocationAuthorized = true
            startLocationUpdates()
        case .authorizedAlways:
            isLocationAuthorized = true
            startLocationUpdates()
        default:
            isLocationAuthorized = false
            locationStatus = "需要位置权限"
        }
    }
    
    // 获取当前运动时长（格式化为时:分:秒）
    var formattedDuration: String {
        guard let startTime = trackingStartTime else { return "00:00:00" }
        
        let duration = Int(Date().timeIntervalSince(startTime))
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // 获取当前配速（分钟/公里）
    var currentPace: String {
        if totalDistance < 10 || currentSpeed <= 0 {
            return "--'--\""
        }
        
        // 计算配速（分钟/公里）
        let paceInSecondsPerKm = (1000 / currentSpeed)
        let minutes = Int(paceInSecondsPerKm / 60)
        let seconds = Int(paceInSecondsPerKm.truncatingRemainder(dividingBy: 60))
        
        return String(format: "%d'%02d\"", minutes, seconds)
    }
    
    // 辅助函数 - 添加到LocationManager类
    private func correctCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 在真机调试中发现轨迹往左上方偏移，尝试校正
        // 使用可配置的偏移值
        if enableCoordinateCorrection {
            return CLLocationCoordinate2D(
                latitude: coordinate.latitude + latitudeOffset,
                longitude: coordinate.longitude + longitudeOffset
            )
        } else {
            return coordinate
        }
    }
    
    // 添加调试日志
    func logCoordinateInfo(_ original: CLLocationCoordinate2D, _ corrected: CLLocationCoordinate2D) {
        print("=== 坐标信息 ===")
        print("原始: 纬度=\(original.latitude), 经度=\(original.longitude)")
        print("校正: 纬度=\(corrected.latitude), 经度=\(corrected.longitude)")
        print("偏移: 纬度=\(latitudeOffset), 经度=\(longitudeOffset)")
        print("===============")
    }
    
    // 重置偏移校正设置
    func resetCorrectionSettings() {
        //latitudeOffset = 0.00005
        //longitudeOffset = 0.00005
        latitudeOffset = -0.002660
        longitudeOffset = 0.005360
    }
    
    // 清除轨迹数据
    func clearRouteData() {
        routeCoordinates.removeAll()
        locationHistory.removeAll()
    }
    
    // 重置缩放级别
    func resetMapZoom() {
        if let location = location {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            needsInitialZoom = true // 标记需要重新设置地图区域
        }
    }
}

struct RouteMapView: UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager
    @Binding var mapType: MKMapType
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // 设置用户跟踪模式
        if locationManager.isLocationLocked {
            mapView.userTrackingMode = .follow
        } else {
            mapView.userTrackingMode = .none
        }
        
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.mapType = mapType
        
        // 禁用地图旋转，保持北向上
        mapView.isRotateEnabled = false
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新地图类型
        mapView.mapType = mapType
        
        // 更新用户跟踪模式 - 只控制位置跟踪，不控制缩放
        if locationManager.isLocationLocked {
            // 使用follow模式但不自动调整缩放级别
            mapView.setUserTrackingMode(.follow, animated: true)
        } else {
            mapView.setUserTrackingMode(.none, animated: false)
        }
        
        // 首次获取位置时，设置地图区域
        if locationManager.needsInitialZoom {
            mapView.setRegion(locationManager.region, animated: true)
            // 确保只在首次设置地图区域后，不再自动更新区域
            locationManager.needsInitialZoom = false
        }
        
        // 清除之前的覆盖物
        mapView.removeOverlays(mapView.overlays)
        
        // 添加路径覆盖物
        if locationManager.routeCoordinates.count > 1 || locationManager.locationHistory.count > 1 {
            // 直接使用用户的位置坐标创建轨迹
            if let userPaths = createUserPathOverlay() {
                mapView.addOverlay(userPaths, level: .aboveRoads)
            }
        }
    }
    
    // 直接使用用户位置历史创建轨迹，应用坐标校正
    private func createUserPathOverlay() -> MKPolyline? {
        if locationManager.locationHistory.count < 2 {
            return nil
        }
        
        // 根据设置决定是否应用坐标校正
        var coordinates: [CLLocationCoordinate2D] = []
        for location in locationManager.locationHistory {
            if locationManager.enableCoordinateCorrection {
                // 应用校正
                let correctedCoord = CLLocationCoordinate2D(
                    latitude: location.coordinate.latitude + locationManager.latitudeOffset,
                    longitude: location.coordinate.longitude + locationManager.longitudeOffset
                )
                coordinates.append(correctedCoord)
            } else {
                // 使用原始坐标
                coordinates.append(location.coordinate)
            }
        }
        
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteMapView
        
        init(_ parent: RouteMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 6
                renderer.alpha = 0.8
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 当用户位置更新时，如果是锁定模式，则仅移动地图中心到用户位置，不改变缩放级别
            if parent.locationManager.isLocationLocked, let location = userLocation.location {
                // 获取当前的缩放级别
                let currentSpan = mapView.region.span
                
                // 创建新的区域，保持缩放级别不变
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: currentSpan // 保持当前缩放级别
                )
                mapView.setRegion(region, animated: true)
            }
        }
    }
}

struct DistanceView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var showLocationAlert = false
    @State private var mapType: MKMapType = .standard
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    // 地图
                    ZStack {
                        RouteMapView(locationManager: locationManager, mapType: $mapType)
                            .frame(height: 300)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .overlay(
                                VStack {
                                    // 位置状态指示器
                                    HStack {
                                        Image(systemName: locationManager.hasInitialLocation ? "location.fill" : "location.slash")
                                            .foregroundColor(locationManager.hasInitialLocation ? .green : .red)
                                        Text(locationManager.locationStatus)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(6)
                                    .background(Color(.systemBackground).opacity(0.8))
                                    .cornerRadius(8)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 10)
                                    
                                    Spacer()
                                    
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 10) {
                                            Button(action: {
                                                mapType = mapType == .standard ? .satellite : .standard
                                            }) {
                                                Image(systemName: mapType == .standard ? "globe" : "map")
                                                    .padding(8)
                                                    .background(Color.white.opacity(0.8))
                                                    .clipShape(Circle())
                                            }
                                            
                                            if locationManager.location != nil {
                                                Button(action: {
                                                    if let location = locationManager.location {
                                                        locationManager.centerMapOnUserLocation(location)
                                                    }
                                                }) {
                                                    Image(systemName: "location.fill")
                                                        .padding(8)
                                                        .background(Color.white.opacity(0.8))
                                                        .clipShape(Circle())
                                                }
                                                
                                                Button(action: {
                                                    locationManager.toggleLocationLock()
                                                }) {
                                                    Image(systemName: locationManager.isLocationLocked ? "lock.fill" : "lock.open.fill")
                                                        .padding(8)
                                                        .background(locationManager.isLocationLocked ? Color.blue.opacity(0.8) : Color.white.opacity(0.8))
                                                        .foregroundColor(locationManager.isLocationLocked ? .white : .black)
                                                        .clipShape(Circle())
                                                }
                                                .overlay(
                                                    Circle()
                                                        .stroke(locationManager.isLocationLocked ? Color.white : Color.blue, lineWidth: 2)
                                                        .opacity(locationManager.isLocationLocked ? 1 : 0.5)
                                                )
                                                
                                                // 添加缩放重置按钮
                                                Button(action: {
                                                    locationManager.resetMapZoom()
                                                }) {
                                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                        .padding(8)
                                                        .background(Color.white.opacity(0.8))
                                                        .clipShape(Circle())
                                                }
                                            }
                                        }
                                        .padding(8)
                                    }
                                }
                            )
                        
                        if !locationManager.isLocationAuthorized {
                            VStack {
                                Text("需要位置权限")
                                    .font(.headline)
                                
                                Button("授权位置") {
                                    locationManager.requestAlwaysAuthorization()
                                    showLocationAlert = true
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding()
                            .background(Color.white.opacity(0.8))
                        .cornerRadius(12)
                        }
                    }
                    
                    // 运动数据概览
                    if locationManager.isTracking {
                        HStack(spacing: 15) {
                            // 时长
                            VStack {
                                Text("时长")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(locationManager.formattedDuration)
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.05), radius: 2)
                            
                            // 配速
                            VStack {
                                Text("配速")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(locationManager.currentPace)
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.05), radius: 2)
                            
                            // 精度
                            VStack {
                                Text("精度")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(locationManager.trackingAccuracy)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.05), radius: 2)
                        }
                        .padding(.horizontal)
                    }
                    
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
                            HStack {
                                Image(systemName: locationManager.isTracking ? "pause.fill" : "play.fill")
                                Text(locationManager.isTracking ? "停止" : "开始")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 120, height: 50)
                            .background(locationManager.isTracking ? Color.red : Color.green)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            locationManager.resetTracking()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("重置")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 120, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.vertical)

                    // 添加清除路径按钮
                    Button(action: {
                        locationManager.clearRouteData()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("清除路径")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)

                    // 简化坐标校正控制
                    VStack(alignment: .leading, spacing: 10) {
                        Text("调试信息")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        if let location = locationManager.location {
                            Text("当前位置: 纬度=\(String(format: "%.6f", location.coordinate.latitude)), 经度=\(String(format: "%.6f", location.coordinate.longitude))")
                                .font(.caption)
                            
                            Text("精度: \(String(format: "%.2f", location.horizontalAccuracy))米")
                                .font(.caption)
                            
                            Text("轨迹点数: \(locationManager.locationHistory.count)")
                                .font(.caption)
                        } else {
                            Text("位置未获取")
                                .font(.caption)
                        }
                        
                        Divider()
                        
                        // 轨迹偏移调整控制
                        HStack {
                            Text("轨迹校正")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: $locationManager.enableCoordinateCorrection)
                                .labelsHidden()
                        }
                        
                        if locationManager.enableCoordinateCorrection {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("纬度偏移: \(String(format: "%.6f", locationManager.latitudeOffset))")
                                        .font(.caption)
                                    Spacer()
                                    
                                    // 粗调按钮
                                    Button("<<") {
                                        locationManager.latitudeOffset -= 0.0005
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(4)
                                    
                                    Button("-") {
                                        locationManager.latitudeOffset -= 0.00001
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.2))
                                    .cornerRadius(4)
                                    
                                    Button("+") {
                                        locationManager.latitudeOffset += 0.00001
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                                    
                                    // 粗调按钮
                                    Button(">>") {
                                        locationManager.latitudeOffset += 0.0005
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(4)
                                }
                                
                                Slider(value: $locationManager.latitudeOffset, in: -0.005...0.005, step: 0.0001)
                                    .frame(maxWidth: .infinity)
                                
                                HStack {
                                    Text("经度偏移: \(String(format: "%.6f", locationManager.longitudeOffset))")
                                        .font(.caption)
                                    Spacer()
                                    
                                    // 粗调按钮
                                    Button("<<") {
                                        locationManager.longitudeOffset -= 0.0005
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(4)
                                    
                                    Button("-") {
                                        locationManager.longitudeOffset -= 0.00001
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.2))
                                    .cornerRadius(4)
                                    
                                    Button("+") {
                                        locationManager.longitudeOffset += 0.00001
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                                    
                                    // 粗调按钮
                                    Button(">>") {
                                        locationManager.longitudeOffset += 0.0005
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(4)
                                }
                                
                                Slider(value: $locationManager.longitudeOffset, in: -0.005...0.005, step: 0.0001)
                                    .frame(maxWidth: .infinity)
                                
                                HStack {
                                    Button("重置") {
                                        locationManager.resetCorrectionSettings()
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(5)
                                    
                                    Spacer()
                                    
                                    Button("应用并清除轨迹") {
                                        locationManager.clearRouteData()
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(5)
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            // 导出轨迹点数据（仅输出到控制台）
                            let historyCount = locationManager.locationHistory.count
                            if historyCount > 0 {
                                print("=== 轨迹数据导出 ===")
                                print("共\(historyCount)个轨迹点")
                                print("当前偏移: 纬度=\(locationManager.latitudeOffset), 经度=\(locationManager.longitudeOffset)")
                                
                                for (index, location) in locationManager.locationHistory.enumerated() {
                                    print("\(index): 纬度=\(location.coordinate.latitude), 经度=\(location.coordinate.longitude), 时间=\(location.timestamp)")
                                }
                                print("=== 导出结束 ===")
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.doc")
                                Text("导出轨迹数据")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(5)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.vertical)
            }
            .navigationTitle("测距")
            .edgesIgnoringSafeArea(.top)
            .alert("位置权限", isPresented: $showLocationAlert) {
                Button("打开设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("需要位置权限来跟踪您的运动轨迹。请在设置中允许此应用使用您的位置。")
            }
            .onAppear {
                // 确保在视图加载时开始位置更新
                locationManager.startLocationUpdates()
            }
        }
    }
}

struct DistanceView_Previews: PreviewProvider {
    static var previews: some View {
        DistanceView()
    }
} 