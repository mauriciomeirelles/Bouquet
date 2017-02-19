//
//  ViewController.swift
//  BouquetExample
//
//  Created by Mauricio de Meirelles on 2/19/17.
//
//

import UIKit
import CoreBluetooth
import CoreLocation
import AVFoundation

let uuidBride = UUID(uuidString: "837F674E-D162-411A-A571-40E91C3B2E67")
let uuidClient = UUID(uuidString:"E0A5C554-F991-4414-8585-26D89F330D43")
let beaconIdentifier = "com.Bouquet.Example"

class ViewController: UIViewController, CLLocationManagerDelegate, CBPeripheralManagerDelegate {

    @IBOutlet weak var lblDescription: UILabel!
    @IBOutlet weak var btBride: UIButton!
    @IBOutlet weak var btStartCountdown: UIButton!
    
    var locationManager = CLLocationManager()
    var peripheralManager:CBPeripheralManager?
    var alreadyAdvertisingClient = false
    var alreadyAdvertisingBride = false
    var u16 : UInt16 = 0
    var countFlash = 0
    let brideDefaultType = "isBride"
    var countDown = 3
    var countDownTimer: Timer?
    var flashBlinkTimer: Timer?
    var canThrow = false
    var clientsArray:[NSNumber] = []
    var shouldTurnClientOnAgain = false
    let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
    let defaults = UserDefaults.standard



    override func viewDidLoad() {
        super.viewDidLoad()
      
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: DispatchQueue.main, options: [CBPeripheralManagerOptionShowPowerAlertKey : false])
        
        self.btBride.setTitle(NSLocalizedString("BRIDE", comment: ""), for: .normal)
        self.btStartCountdown.setTitle(NSLocalizedString("COUNTDOWN", comment: ""), for: .normal)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.backFromBackground), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.goingToBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        
        if defaults.bool(forKey: brideDefaultType) == true {
            self.lblDescription.text = ""
            self.btBride.isHidden = true
            self.btStartCountdown.isHidden = false
        } else {
            self.lblDescription.text = NSLocalizedString("WAITING", comment: "")
            self.btBride.isHidden = false
            self.btStartCountdown.isHidden = true
        }
        
    }

    
    func startClient()
    {
        if !alreadyAdvertisingClient {
            self.peripheralManager?.stopAdvertising()
            
            let beaconRegionBrideForRanging = CLBeaconRegion(proximityUUID: uuidBride!, identifier: beaconIdentifier)
            let beaconRegionClientForRanging = CLBeaconRegion(proximityUUID: uuidClient!, identifier: beaconIdentifier)
            
            locationManager.stopRangingBeacons(in: beaconRegionClientForRanging)
            
            locationManager.startMonitoring(for: beaconRegionBrideForRanging)
            locationManager.startRangingBeacons(in: beaconRegionBrideForRanging)
            
            var uuidBytes: [UInt8] = [UInt8](repeating: 0, count: 16)
            let uuidAux = UIDevice.current.identifierForVendor! as NSUUID
            
            uuidAux.getBytes(&uuidBytes)
            
            let uuidData = NSData(bytes: &uuidBytes, length: 16)
            (uuidData as NSData).getBytes(&u16, length: 16)
            let beaconRegionClient = CLBeaconRegion(proximityUUID: uuidClient!, major: u16,identifier: beaconIdentifier)
            
            
            let advertisedDataClient = beaconRegionClient.peripheralData(withMeasuredPower: -58) as? NSDictionary
            self.peripheralManager?.startAdvertising(advertisedDataClient as! [String: AnyObject]!)
            
            alreadyAdvertisingBride = false
            alreadyAdvertisingClient = true
            
        }
        
    }
    
    
    
    func startBride()
    {
        if !alreadyAdvertisingBride {
            self.peripheralManager?.stopAdvertising()
            
            let beaconRegionBrideForRanging = CLBeaconRegion(proximityUUID: uuidBride!, identifier: beaconIdentifier)
            let beaconRegionClientForRanging = CLBeaconRegion(proximityUUID: uuidClient!, identifier: beaconIdentifier)
            
            locationManager.startMonitoring(for: beaconRegionClientForRanging)
            
            locationManager.stopRangingBeacons(in: beaconRegionBrideForRanging)
            locationManager.startRangingBeacons(in: beaconRegionClientForRanging)
            
            let beaconRegionBride = CLBeaconRegion(proximityUUID: uuidBride!, major: 0, identifier: beaconIdentifier)
            let advertisedDataBride = beaconRegionBride.peripheralData(withMeasuredPower: -58) as? NSDictionary
            self.peripheralManager?.startAdvertising(advertisedDataBride as! [String: AnyObject]!)
            
            alreadyAdvertisingBride = true
            alreadyAdvertisingClient = false
        }
        
        
    }

    
    func toggleFlash() {
        if countFlash < 200 {
            try! device?.lockForConfiguration()
            if (device?.torchMode == AVCaptureTorchMode.on) {
                device?.torchMode = AVCaptureTorchMode.off
            } else {
                try! device?.setTorchModeOnWithLevel(1.0)
            }
            device?.unlockForConfiguration()
            countFlash += 1
        } else {
            try! device?.lockForConfiguration()
            device?.torchMode = AVCaptureTorchMode.off
            device?.unlockForConfiguration()
            
            flashBlinkTimer?.invalidate()
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        switch peripheral.state {
        case .poweredOn:
            DispatchQueue.main.async(execute: { () -> Void in
                if self.defaults.bool(forKey: self.brideDefaultType) == false {
                    self.startClient()
                } else {
                    self.startBride()
                }
            })
            break
            
        case .poweredOff:
            self.peripheralManager?.stopAdvertising()
            break
        default:
            break
        }
        
    }
    
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if ((region as! CLBeaconRegion).proximityUUID ==  uuidBride) {
            sendLocalNotificationWithMessage(NSLocalizedString("TOSS", comment: ""))
        }
    }

    func sendLocalNotificationWithMessage(_ message: String!) {
        let notification:UILocalNotification = UILocalNotification()
        notification.alertBody = message
        UIApplication.shared.scheduleLocalNotification(notification)
    }
    

    @IBAction func btBrideSelected(_ sender: Any) {
        defaults.set(true, forKey: brideDefaultType)
        defaults.synchronize()
        
        self.lblDescription.text = ""
        self.btStartCountdown.isHidden = false
        self.btStartCountdown.isEnabled = false
        self.btBride.isHidden = true
        
        startBride()
    }
    
    @IBAction func tossBouquet(_ sender: UIButton) {
        self.btStartCountdown.isHidden = true
        self.lblDescription.text = "3"
        countDownTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.countDownBouquet), userInfo: nil, repeats: true)
    }
    
    
    func countDownBouquet() {
        countDown -= 1
        
        if countDown > 0 {
            self.lblDescription.text = "\(countDown)"
        } else {
            canThrow = true
            countDownTimer?.invalidate()
            self.lblDescription.text = NSLocalizedString("SHAKE", comment: "")
        }
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            if(clientsArray.count > 0 && canThrow) {
                canThrow = false
                
                let beaconRegionClientForRanging = CLBeaconRegion(proximityUUID: uuidClient!, identifier: beaconIdentifier)
                
                self.peripheralManager?.stopAdvertising()
                self.locationManager.stopRangingBeacons(in: beaconRegionClientForRanging)
                
                let numberMajorAux = clientsArray[randomInt(0, max: clientsArray.count-1)]
                let int16Aux = numberMajorAux.uint16Value
                let beaconRegionBrideForBouquet = CLBeaconRegion(proximityUUID: uuidBride!, major: int16Aux,
                                                                 identifier: beaconIdentifier)
                
                let advertisedDataForBride = beaconRegionBrideForBouquet.peripheralData(withMeasuredPower: -58) as? NSDictionary
                self.peripheralManager!.startAdvertising(advertisedDataForBride as! [String: AnyObject]!)
                
                shouldTurnClientOnAgain = true

                self.lblDescription.text = NSLocalizedString("ENJOY", comment: "")
                
            }
            
        }
    }
    
    func randomInt(_ min: Int, max:Int) -> Int {
        return min + Int(arc4random_uniform(UInt32(max - min + 1)))
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        
        if defaults.bool(forKey: brideDefaultType) == false {
            if beacons.count > 0  {
                let beacon = beacons.first!
                let majorAux = beacon.major.uint16Value
                self.btBride.isHidden = true
                
                if u16 == majorAux {
                    let beaconRegionBrideForRanging = CLBeaconRegion(proximityUUID: uuidBride!, identifier: beaconIdentifier)
                    self.locationManager.stopRangingBeacons(in: beaconRegionBrideForRanging)
                    self.shouldTurnClientOnAgain = true

                    self.lblDescription.text = NSLocalizedString("WIN", comment: "")

                    //Party Rock
                    if (device?.hasTorch)! {
                        toggleFlash()
                        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                        flashBlinkTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(ViewController.toggleFlash), userInfo: nil, repeats: true)
                    }
                } else if majorAux == 0 {
                    self.lblDescription.text = NSLocalizedString("WAITING_TOSS", comment: "")
                } else {
                    self.lblDescription.text = NSLocalizedString("NOT_TODAY", comment: "")
                }
            } else {
                self.lblDescription.text = NSLocalizedString("WAITING", comment: "")
                self.btBride.isHidden = false
            }
        } else {
            
            clientsArray.removeAll(keepingCapacity: false)
            for beacon in beacons {
                clientsArray.append(beacon.major)
            }
            
            if beacons.count > 0 {
                self.btStartCountdown.isEnabled = true
            } else {
                self.btStartCountdown.isEnabled = false
            }
            
        }
    }
    
    
    
    func backFromBackground() {
        
        self.countDown = 3
        
        if self.defaults.bool(forKey: self.brideDefaultType) == false {
            self.lblDescription.text = NSLocalizedString("WAITING", comment: "")
            self.btBride.isHidden = false
            
            if (shouldTurnClientOnAgain) {
                shouldTurnClientOnAgain = false
                startClient()
            }
            
        } else {
            self.lblDescription.text = ""
            self.btBride.isHidden = true
        }
    }
    
    func goingToBackground() {
        countDownTimer?.invalidate()
        alreadyAdvertisingClient = false
        alreadyAdvertisingBride = false
        flashBlinkTimer?.invalidate()
        
        if defaults.bool(forKey: brideDefaultType) == true && (countDown == 1 || countDown == 0) {
            defaults.set(false, forKey: brideDefaultType)
            defaults.synchronize()
            
            //Stop Bride
            let beaconRegionClientForRanging = CLBeaconRegion(proximityUUID: uuidClient!, identifier: beaconIdentifier)
            self.peripheralManager?.stopAdvertising()
            locationManager.stopRangingBeacons(in: beaconRegionClientForRanging)
            
        }
        
    }

    
}

