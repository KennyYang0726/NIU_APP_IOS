import CoreLocation



final class SingleLocationManager: NSObject, CLLocationManagerDelegate {

    static let shared = SingleLocationManager()

    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?) -> Void)?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// 取得一次性定位
    func requestSingleLocation(_ completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.completion = completion
        
        let status = manager.authorizationStatus
        
        switch status {
        case .notDetermined:
            // 第一次請求授權
            manager.requestWhenInUseAuthorization()
            
        case .authorizedWhenInUse, .authorizedAlways:
            // 已授權 → 抓一次
            manager.requestLocation()
            
        case .denied, .restricted:
            // 沒授權 → 回傳 nil
            completion(nil)
            self.completion = nil
            
        @unknown default:
            completion(nil)
            self.completion = nil
        }
    }

    // MARK: - 授權改變時（iOS 14+）
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        // 若剛授權完成 → 再抓一次
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    // MARK: - 定位成功
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.first?.coordinate
        completion?(coord)
        completion = nil
    }

    // MARK: - 定位失敗
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil)
        completion = nil
    }
}
