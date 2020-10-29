//
//  ViewController.swift
//  Location
//
//  Created by Alessandro on 2020/08/01.
//  Copyright © 2020 Alessandro. All rights reserved.
//

import UIKit
import CoreLocation

extension Date {
    var millisecondsSince1970:Double {
        return Double((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds:Double) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
    
    static var tomorrow:  Date { return Date().dayAfter }
    var dayAfter: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: noon)!
    }
    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
}
extension Collection where Indices.Iterator.Element == Index {
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
extension Double {
    func toInt() -> Int {
        if self >= Double(Int.min) && self < Double(Int.max) {
            return Int(self)
        } else {
            return -1
        }
    }
    var toRadians: Double { return self * .pi / 180 }
}
extension CGFloat {
  var degreesToRadians: CGFloat { return self * .pi / 180 }
  var radiansToDegrees: CGFloat { return self * 180 / .pi }
}
private extension Double {
  var degreesToRadians: Double { return Double(CGFloat(self).degreesToRadians) }
  var radiansToDegrees: Double { return Double(CGFloat(self).radiansToDegrees) }
}
extension String: Error {}

class ViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var mainField: UITextView!
    @IBOutlet weak var units: UISwitch!
    @IBOutlet weak var lookAhead: UITextField!
    @IBOutlet weak var coords: UILabel!
    @IBOutlet weak var compass: UIImageView!
    @IBOutlet weak var crossTrack: UISwitch!
    
    var tracks: [[Double]] = [];
    var poi: [(Double, Double, Double, Double, String, String, String)] = [];

    var current: [Double]? = nil
    var goal: [Double]? = nil
    
    let locationManager:CLLocationManager = CLLocationManager()
    
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)

        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        
        let path = Bundle.main.path(forResource: "bruce_all", ofType: "txt")
        do {
            let text = try String(contentsOfFile: path!, encoding: .utf8)
            var text_array = text.components(separatedBy: ";")
            text_array = text_array.map {
                let tmp = $0.components(separatedBy: " = ")
                return tmp[tmp.count-1]
            }
            let text_array_2 = text_array.map {
                $0.replacingOccurrences(of: "[[", with: "")
                  .replacingOccurrences(of: "]]", with: "")
                  .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "\\n", with: "")
                  .components(separatedBy: "], [").map {
                    $0.components(separatedBy: ", ")
                }
            }

            for i in text_array_2.first! {
                var tmp: [Double] = [];
                for el in i {
                    tmp.append((el as NSString).doubleValue);
                }
                tracks.append(tmp)
            }
            for j in text_array_2.last! {
                poi.append(((j[0] as NSString).doubleValue,
                            (j[1] as NSString).doubleValue,
                            (j[2] as NSString).doubleValue,
                            (j[3] as NSString).doubleValue,
                            j[4].trimmingCharacters(in: .whitespacesAndNewlines),
                            j[5].trimmingCharacters(in: .whitespacesAndNewlines),
                            j[6].trimmingCharacters(in: .whitespacesAndNewlines)));
            }
        }
        catch {/* error handling here */}
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
      UIView.animate(withDuration: 0.5) {
        let angle = self.bearingToLocationRadian(location: self.current!, destination: self.goal!) - newHeading.trueHeading.degreesToRadians
        self.compass.transform = CGAffineTransform(rotationAngle: CGFloat(angle)) // rotate the picture
      }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for currentLocation in locations {
            let look_ahead: Double = Double(lookAhead.text!) ?? 0
            var output : String = "";
            let result = min_distance(data: tracks,
                                      lat: currentLocation.coordinate.latitude,
                                      lon: currentLocation.coordinate.longitude);

            let kms = result["trail"] as! [Double];
            current = [currentLocation.coordinate.latitude, currentLocation.coordinate.longitude]
            goal = [kms[0], kms[1]]
            
//            if result["up"] as! Bool {
//                output += tracks[(result["index"] as! Int) + 1].reduce("") { $0 + ", " + String($1) } + "\n";
//            } else {
//                output += tracks[(result["index"] as! Int) - 1].reduce("") { $0 + ", " + String($1) }
//            }
            
            output += "Mileage: \(display_km(km: kms[3])) +/- \(display_m(m: currentLocation.horizontalAccuracy))\n"
            if (result["off"] as! Double > 0.025) {
                locationManager.startUpdatingHeading()
                compass.isHidden = false
                output += "Off Trail: \(display_km(km: result["off"] as! Double))\n"
            } else {
                locationManager.stopUpdatingHeading()
                compass.isHidden = true
            }
            output += "Altitude: \(display_m(m: currentLocation.altitude)) +/- \(display_m(m: currentLocation.verticalAccuracy))\n\n"
            
            let future = subarray_distance(data: tracks, offset: result["index"] as! Int, goal: !units.isOn ? mile2km(mile: look_ahead) : look_ahead)
            
            output += "Goal: \(display_km(km: (future["trail"] as! [Double])[3]))\n"
            output += "Elevation: +\(display_m(m: future["gain"]! as! Double)) / \(display_m(m: future["loss"]! as! Double))\n\n"
            
            let points_of_interest = upcoming_poi(data: tracks, way_points: poi, offset: result["index"] as! Int, goal: !units.isOn ? mile2km(mile: look_ahead) : look_ahead)["poi"] as! [(Double, Double, Double, Double, String, String, String)];
            if (points_of_interest.count > 0) {
              output += "Upcoming:\n"
            }
            for point in points_of_interest {
                var out: String = "\(display_km(km: point.3 - tracks[result["index"] as! Int][3]))\n\t\(point.4)\n\t\(point.5)"
                if (point.6.count > 0) {
                    out += "\n\t\(point.6)"
              }
                output += out + "\n"
            }
            if (points_of_interest.count > 0) {
              output += "\n"
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "hh:mm"

            let sun_times_today = sun(position: currentLocation.coordinate);
            let sun_times_tomorrow = sun(position: currentLocation.coordinate, date: Date.tomorrow);

            let sun_time_left = (sun_times_today["set"]!.timeIntervalSince1970 - Date().timeIntervalSince1970) / 3600
            let sun_time_tomorrow = (sun_times_tomorrow["set"]!.timeIntervalSince1970 - sun_times_tomorrow["rise"]!.timeIntervalSince1970) / 3600

            if sun_time_left > 0 {
                output += "Sun Left: \(display_time(time: sun_time_left)) ↓\(formatter.string(from: sun_times_today["set"]!))\n"
            }
            output += "Sun Tmrw: \(display_time(time: sun_time_tomorrow)) ↑\(formatter.string(from: sun_times_tomorrow["rise"]!))\n\n"
            
            coords.text = "<" + String(format: "%.4f", currentLocation.coordinate.latitude) + ", " + String(format: "%.4f", currentLocation.coordinate.longitude) + ">\n\n"

            mainField.text = output;
        }
    }
    
    func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
      let deg2rad = 0.017453292519943295;
        var lat1 = lat1;
        var lat2 = lat2;
        var lon1 = lon1;
        var lon2 = lon2;
      lat1 *= deg2rad;
      lon1 *= deg2rad;
      lat2 *= deg2rad;
      lon2 *= deg2rad;
      let a = (
        (1 - cos(lat2 - lat1)) +
        (1 - cos(lon2 - lon1)) * cos(lat1) * cos(lat2)
      ) / 2;

      return 12742 * asin(sqrt(a));
    }
    
    func bearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let o1 = lat1.toRadians;
        let o2 = lat2.toRadians;
        let dh = (lon2 - lon1).toRadians;
        
        let x = cos(o1) * sin(o2) - sin(o1) * cos(o2) * cos(dh);
        let y = sin(dh) * cos(o2)
        return (atan2(y, x).radiansToDegrees as Double).truncatingRemainder(dividingBy: 360)
    }
    
    func crossTrackDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double, lat3 : Double, lon3 : Double) -> Double {
        let radius = 6371e3;
        
        let d13 = distance(lat1: lat1, lon1: lon1, lat2: lat3, lon2: lon3) / radius * 1000;
        let o13 = bearing(lat1: lat1, lon1: lon1, lat2: lat3, lon2: lon3).toRadians;
        let o12 = bearing(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2).toRadians;
        
        let dxt = asin(sin(d13) * sin(o13 - o12))
        
        return abs(dxt * radius) / 1000;
    }
    
    func min_distance(data: [[Double]], lat: Double, lon: Double) -> [String:Any] {
        var off_track: Double = data[data.count-1][3];
        var point: [Double] = [];
        var index: Int = data.count-1;
      for (i, d_) in data.enumerated() {
        let d: Double = distance(lat1: d_[0], lon1: d_[1], lat2: lat, lon2: lon)
        if (d <= off_track) {
          point = d_;
          off_track = d;
          index = i;
        }
      }
        var up : Bool = false;
        if crossTrack.isOn {
            let try1 = distance(lat1: data[index + 1][0], lon1: data[index + 1][1], lat2: lat, lon2: lon)
            let try2 = distance(lat1: data[index - 1][1], lon1: data[index - 1][1], lat2: lat, lon2: lon)
            if (try1 <= try2) {
                off_track = crossTrackDistance(lat1: data[index][0], lon1: data[index][1], lat2: data[index + 1][0], lon2: data[index + 1][1], lat3: lat, lon3: lon)
                up = true;
            } else {
                off_track = crossTrackDistance(lat1: data[index - 1][0], lon1: data[index - 1][1], lat2: data[index][0], lon2: data[index][1], lat3: lat, lon3: lon)
                up = false;
            }
        }

        if (index == data.count-1) { point = data.last! }
        return ["index": index, "off": off_track, "trail": point, "up": up];
    }
    
    func subarray_distance(data: [[Double]], offset: Int, goal: Double) -> [String:Any] {
      let max = data[offset][3] + goal;
        var up: Double = 0;
        var down: Double = 0;
        var index = 0;
        for i in stride(from: offset, to: data.count, by: 1) {
            do {
                index = i;
        if (data[i][3] >= max) {
          return ["index": i, "gain": up, "loss": down, "trail": data[i]];
        }

        let curr = data[i][2];
                let next = data[safe: i + 1]?[2];
                if next == nil { throw "Something" } else {

        let diff = next! - curr;
        if (diff >= 0) {
          up += diff;
        } else {
          down += diff;
        }
                }}
            catch {
                return ["index": i, "gain": up, "loss": down, "trail": data[i]];
            }
      }
        return ["index": index, "gain": up, "loss": down, "trail": data[index]];
    }
    
    func upcoming_poi(data: [[Double]], way_points: [(Double, Double, Double, Double, String, String, String)], offset: Int, goal: Double) -> [String:[Any]] {
      let max = data[offset][3] + goal;
      let min = data[offset][3];
        var poi_list: [(Double, Double, Double, Double, String, String, String)] = [];
        for point in way_points {
            if (point.3 <= max && point.3 >= min) {
          poi_list.append(point);
        }
      }
        poi_list = poi_list.sorted(by: {Double($0.3) < Double($1.3)})
      return ["poi": poi_list]
    }
    
    func display_km(km: Double, decimal: Double = 2) -> String {
      let places = pow(10.0, decimal)
        if (!units.isOn) {
        let miles = km2mile(km: km);
        if (miles < 0.094697) {
          return String(round(miles * 5280)) + " ft";
        }
        return String(round(miles * places) / places) + " miles";
      }
      if (km < 1.5) {
        return String(round(km * 1000)) + " m";
      }
      return String(round(km * places) / places) + " km";
    }

    func display_m(m: Double) -> String {
        if (!units.isOn) {
            return String(m2ft(m: m).toInt()) + " ft";
      }
      return String(m.toInt()) + " m";
    }
    
    func display_time(time: Double) -> String {
        if time < 1 {
            return String((time * 60).toInt()) + "min"
        }
        return String(time.toInt()) + "h"
    }
    
    func km2mile(km: Double) -> Double {
      return km / 1.609344
    }

    func mile2km(mile: Double) -> Double {
      return mile * 1.609344
    }

    func m2ft(m: Double) -> Double {
      return m * 3.28084
    }
    
    func rad(deg: Double) -> Double {
        return deg * Double.pi / 180.0;
    }

    func deg(rad: Double) -> Double {
        return rad * 180.0 / Double.pi;
    }
    
    func sun(position: CLLocationCoordinate2D, date: Date = Date()) -> [String:Date] {
        let lat = position.latitude;
        let lon = position.longitude;

        let n = Double(Int(date.millisecondsSince1970 / 86400000 + 2440587.5)) - 2451545.0 + 0.0008

        let J_star = n - (lon / 360.0);

        let M = (357.5291 + 0.98560028 * J_star).truncatingRemainder(dividingBy: 360)

        let C = (1.9148 * sin(rad(deg: M))) + (0.0200 * sin(rad(deg: 2 * M))) + ( 0.0003 * sin(rad(deg: 3 * M)))

        let lam = (M + C + 180 + 102.9372).truncatingRemainder(dividingBy: 360)

        let J_transit = 2_451_545.0 + J_star + (0.0053 * sin(rad(deg: M))) - (0.0069 * sin(rad(deg: 2 * lam)));

        let delta = asin(sin(rad(deg: lam)) * sin(rad(deg: 23.44)));

        let t = sin(rad(deg: -0.83)) - sin(rad(deg: lat)) * sin(delta);
        let b = cos(rad(deg: lat)) * cos(delta);
        let omega = deg(rad: acos(t / b));

        let rise = J_transit - (omega / 360);
        let set = J_transit + (omega / 360);

        let rise_time = Date(milliseconds: (rise - 2440587.5) * 86400000)
        let set_time = Date(milliseconds: (set - 2440587.5) * 86400000)
        
        return ["rise": rise_time, "set": set_time]
    }
    
    func bearingToLocationRadian(location: [Double], destination: [Double]) -> Double {
      
      let lat1 = location[0].degreesToRadians
      let lon1 = location[1].degreesToRadians
      
      let lat2 = destination[0].degreesToRadians
      let lon2 = destination[1].degreesToRadians
      
      let dLon = lon2 - lon1
      
      let y = sin(dLon) * cos(lat2)
      let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
      let radiansBearing = atan2(y, x)
      
      return radiansBearing
    }
}

