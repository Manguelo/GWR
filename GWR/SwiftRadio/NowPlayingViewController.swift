//
//  NowPlayingViewController.swift
//  Swift Radio
//
//  Created by Matthew Fecher on 7/22/15.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import UIKit
import MediaPlayer
import JavaScriptCore

//*****************************************************************
// Protocol
// Updates the StationsViewController when the track changes
//*****************************************************************

protocol NowPlayingViewControllerDelegate: class {
    func songMetaDataDidUpdate(track: Track)
    func artworkDidUpdate(track: Track)
    func trackPlayingToggled(track: Track)
}

//*****************************************************************
// NowPlayingViewController
//*****************************************************************
var playingRadio = false
class NowPlayingViewController: UIViewController {

    @IBOutlet weak var albumHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var albumImageView: SpringImageView!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var songLabel: SpringLabel!
    @IBOutlet weak var stationDescLabel: UILabel!
    @IBOutlet weak var volumeParentView: UIView!
    @IBOutlet weak var slider = UISlider()
    
    var currentStation: RadioStation!
    var downloadTask: URLSessionDownloadTask?
    var iPhone4 = false
    var justBecameActive = false
    var newStation = true
    var nowPlayingImageView: UIImageView!
    let radioPlayer = Player.radio
    var track: Track!
    var mpVolumeSlider = UISlider()
    var radioIsLoading = true
    
    weak var delegate: NowPlayingViewControllerDelegate?
    
    //*****************************************************************
    // MARK: - ViewDidLoad
    //*****************************************************************
    
    override func viewDidLoad() {
/* schedule START */
       
        //in case the array isn't filled to 97 (error with schedule on Google Drive)
        if(scheduleArray.count < 97){
            for _ in 1...(97-scheduleArray.count){
                scheduleArray.append("WAYG-LP 104.7")
                scheduleArray.append("God's Way Radio")
            }
        }
        //print(webString)
        print("\n\n")
        print(scheduleArray)
        print("\n\n")

/* schedule END */
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        //AVAudioSession.sharedInstance().setCategory(AVAudioSessionCa‌​tegoryPlayback)
        super.viewDidLoad()
        var timer = Timer()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(setUpArtistAndTitle), userInfo: nil, repeats: true)
      
        // Setup handoff functionality - GH
        setupUserActivity()
        
        // Set AlbumArtwork Constraints
        optimizeForDeviceSize()

        // Set View Title
        self.title = "God's Way Radio"
        
        // Create Now Playing BarItem
        createNowPlayingAnimation()
        
        // Setup MPMoviePlayerController
        // If you're building an app for a client, you may want to
        // replace the MediaPlayer player with a more robust 
        // streaming library/SDK. Preferably one that supports interruptions, etc.
        // Most of the good streaming libaries are in Obj-C, however they
        // will work nicely with this Swift code. There is a branch using RadioKit if 
        // you need an example of how nicely this code integrates with libraries.
        setupPlayer()
        
        // Notification for when app becomes active
        NotificationCenter.default.addObserver(self,
            selector: #selector(NowPlayingViewController.didBecomeActiveNotificationReceived),
            name: Notification.Name("UIApplicationDidBecomeActiveNotification"),
            object: nil)
        
        // Notification for MediaPlayer metadata updated
      //  NotificationCenter.default.addObserver(self,
        //    selector: #selector(NowPlayingViewController.metadataUpdated),
          //  name: Notification.Name.MPMoviePlayerTimedMetadataUpdated,
            //object: nil)
        
        // Notification for AVAudioSession Interruption (e.g. Phone call)
        NotificationCenter.default.addObserver(self,
            selector: #selector(NowPlayingViewController.sessionInterrupted),
            name: Notification.Name.AVAudioSessionInterruption,
            object: AVAudioSession.sharedInstance())
        
        // Check for station change
        if newStation {
            track = Track()
            stationDidChange()
        } else {
            updateLabels()
            albumImageView.image = track.artworkImage

            if !track.isPlaying {
                pausePressed()
            } else {
                nowPlayingImageView.startAnimating()
            }
        }
        nowPlayingImageView.startAnimating()
        // Setup slider
        setupVolumeSlider()
        playingRadio = true
    }
    
    @objc func didBecomeActiveNotificationReceived() {
        // View became active
        updateLabels()
        justBecameActive = true
        updateAlbumArtwork()
    }
    
    deinit {
        // Be a good citizen
        NotificationCenter.default.removeObserver(self,
            name: Notification.Name("UIApplicationDidBecomeActiveNotification"),
            object: nil)
        NotificationCenter.default.removeObserver(self,
            name: Notification.Name.MPMoviePlayerTimedMetadataUpdated,
            object: nil)
        NotificationCenter.default.removeObserver(self,
            name: Notification.Name.AVAudioSessionInterruption,
            object: AVAudioSession.sharedInstance())
    }
    
    //*****************************************************************
    // MARK: - Get JS from website
    //*****************************************************************
    func runScheduleJS(day: String) -> String{
        if let url = URL(string: scheduleJSLink) {
            do {
                let contents = try String(contentsOf: url)
                print()
                
                //let path = Bundle.main.path(forResource: "scheduleV2", ofType: "js")
                let jsSource = contents//try! String(contentsOfFile: path!)//contents
                //"var testFunct = function(message) { return \"Test Message: \" + message;}"
                
                let context = JSContext()
                context?.evaluateScript(jsSource)
                
                if day == "Saturday"{
                    let testFunction = context?.objectForKeyedSubscript("getScheduleSaturday")
                    let result = testFunction?.call(withArguments: nil)
                    if (result?.isString)!{
                        return (result?.toString())!
                    }
                }else if day == "Sunday"{
                    let testFunction = context?.objectForKeyedSubscript("getScheduleSunday")
                    let result = testFunction?.call(withArguments: nil)
                    if (result?.isString)!{
                        return (result?.toString())!
                    }
                }else{
                    let testFunction = context?.objectForKeyedSubscript("getSchedule")
                    let result = testFunction?.call(withArguments: nil)
                    if (result?.isString)!{
                        return (result?.toString())!
                    }
                }
                
            } catch {
                // contents could not be loaded
            }
        } else {
        }
        return "WAYG 104.7 - God's Way Radio"
    }
    
    //*****************************************************************
    // MARK: - Setup
    //*****************************************************************
    
    @objc func setUpArtistAndTitle(){
        let date = Date()
        let calendar = Calendar.current
        let locale = NSTimeZone.init(abbreviation: "EST")
        NSTimeZone.default = locale! as TimeZone
        
        // let hour = calendar.component(.hour, from: date)
        //let minutes = calendar.component(.minute, from: date)
        //let seconds = calendar.component(.second, from: date)
        //let time = hour
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ccc"
        let dayOfWeekString = dateFormatter.string(from: date)
        //print(dayOfWeekString)
        
        if dayOfWeekString == "Sat" {
            let splitString = runScheduleJS(day: "Saturday").components(separatedBy: "-")
            
            artistLabel.text = splitString[1]
            songLabel.text = splitString[0]
        }else if dayOfWeekString == "Sun"{
            let splitString = runScheduleJS(day: "Sunday").components(separatedBy: "-")
            
            artistLabel.text = splitString[1]
            songLabel.text = splitString[0]
        }else if dayOfWeekString == "Mon" || dayOfWeekString == "Tue" || dayOfWeekString == "Wed" || dayOfWeekString == "Thu" || dayOfWeekString == "Fri"{
            let splitString = runScheduleJS(day: "Weekday").components(separatedBy: "-")
            
            artistLabel.text = splitString[1]
            songLabel.text = splitString[0]
        }
        self.updateLockScreen()
        if radioPlayer.currentItem?.status != AVPlayerItemStatus.readyToPlay{
            artistLabel.text = "God's Way Radio"
            songLabel.text = "Loading..."
            radioIsLoading = true
            
        }else{
            songLabel.layer.removeAnimation(forKey: "flash")
            radioIsLoading = false
        }
        
    }
    
    func setupPlayer() {
//        radioPlayer.view.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
//        radioPlayer.view.sizeToFit()
//        radioPlayer.movieSourceType = MPMovieSourceType.streaming
//        radioPlayer.isFullscreen = false
//        radioPlayer.shouldAutoplay = true
//        radioPlayer.prepareToPlay()
//        radioPlayer.controlStyle = MPMovieControlStyle.none
    }
  
    func setupVolumeSlider() {
        // Note: This slider implementation uses a MPVolumeView
        // The volume slider only works in devices, not the simulator.
        volumeParentView.backgroundColor = UIColor.clear
        let volumeView = MPVolumeView(frame: volumeParentView.bounds)
        for view in volumeView.subviews {
            let uiview: UIView = view as UIView
            if (uiview.description as NSString).range(of: "MPVolumeSlider").location != NSNotFound {
                mpVolumeSlider = (uiview as! UISlider)
            }
        }
        
        let thumbImageNormal = UIImage(named: "slider-ball")
        slider?.setThumbImage(thumbImageNormal, for: .normal)
        
    }
    
    func stationDidChange() {
        radioPlayer.pause()
        
//        radioPlayer.contentURL = URL(string: "http://50.22.253.46/wayg-fm")
//        radioPlayer.prepareToPlay()
        let item = AVPlayerItem(url: URL(string: "http://ic2.christiannetcast.com/wayg-fm")!)
        radioPlayer.replaceCurrentItem(with: item)
        playPressed()
        
        if radioIsLoading == true{
            songLabel.animation = "flash"
            songLabel.repeatCount = Float.infinity
            songLabel.animate()
        }
        //updateLabels(statusMessage: "Loading Station...")
        
        // songLabel animate
        updateLabels(statusMessage: "WAYG - 104.7")
        resetAlbumArtwork()
        
        track.isPlaying = true
    }
    
    //*****************************************************************
    // MARK: - Player Controls (Play/Pause/Volume)
    //*****************************************************************
    
    @IBAction func playPressed() {
        track.isPlaying = true
        playingRadio = true
        playButtonEnable(enabled: false)
        radioPlayer.play()
        //updateLabels(statusMessage: "Playing")
        
        if radioIsLoading == true{
            songLabel.animation = "flash"
            songLabel.repeatCount = Float.infinity
            songLabel.animate()
        }
        // Start NowPlaying Animation
        nowPlayingImageView.startAnimating()
        
        // Update StationsVC
        self.delegate?.trackPlayingToggled(track: self.track)
    }
    
    @IBAction func pausePressed() {
        track.isPlaying = false
        playingRadio = false
        playButtonEnable()
        
        radioPlayer.pause()
        //updateLabels(statusMessage: "Station Paused...")
        nowPlayingImageView.stopAnimating()
        
        // Update StationsVC
        self.delegate?.trackPlayingToggled(track: self.track)
    }
    
    @IBAction func volumeChanged(_ sender:UISlider) {
        mpVolumeSlider.value = sender.value
    }
    
    //*****************************************************************
    // MARK: - UI Helper Methods
    //*****************************************************************
    
    func optimizeForDeviceSize() {
        
        // Adjust album size to fit iPhone 4s, 6s & 6s+
        let deviceHeight = self.view.bounds.height
        
        if deviceHeight == 480 {
            iPhone4 = true
            albumHeightConstraint.constant = 106
            view.updateConstraints()
        } else if deviceHeight == 667 {
            albumHeightConstraint.constant = 230
            view.updateConstraints()
        } else if deviceHeight > 667 {
            albumHeightConstraint.constant = 260
            view.updateConstraints()
        }
    }
    
    func updateLabels(statusMessage: String = "") {
        
        if statusMessage != "" {
            // There's a an interruption or pause in the audio queue
            songLabel.text = statusMessage
            artistLabel.text = "God's Way Radio"
            
        } else {
            // Radio is (hopefully) streaming properly
            if track != nil {
                songLabel.text = track.title
                artistLabel.text = track.artist
            }
        }
        
        // Hide station description when album art is displayed or on iPhone 4
        if track.artworkLoaded || iPhone4 {
            stationDescLabel.isHidden = true
        } else {
            stationDescLabel.isHidden = false
            stationDescLabel.text = "Calvary Chapel Miami"
        }
    }
    
    func playButtonEnable(enabled: Bool = true) {
        if enabled {
            playButton.isEnabled = true
            pauseButton.isEnabled = false
            track.isPlaying = false
        } else {
            playButton.isEnabled = false
            pauseButton.isEnabled = true
            track.isPlaying = true
        }
    }
    
    func createNowPlayingAnimation() {
        
        // Setup ImageView
        nowPlayingImageView = UIImageView(image: UIImage(named: "NowPlayingBars-3")?.imageWithColor(tintColor: UIColor.red))
        nowPlayingImageView.autoresizingMask = []
        nowPlayingImageView.contentMode = UIViewContentMode.center
        
        // Create Animation
        nowPlayingImageView.animationImages = AnimationFrames.createFrames()
        nowPlayingImageView.animationDuration = 0.7
        
        // Create Top BarButton
        let barButton = UIButton(type: UIButtonType.custom)
        barButton.frame = CGRect(x: 0,y: 0,width: 40,height: 40);
        barButton.addSubview(nowPlayingImageView)
        nowPlayingImageView.center = barButton.center
        
        let barItem = UIBarButtonItem(customView: barButton)
        self.navigationItem.rightBarButtonItem = barItem
        
    }
    
    func startNowPlayingAnimation() {
        nowPlayingImageView.startAnimating()
    }
    
    //*****************************************************************
    // MARK: - Album Art
    //*****************************************************************
    
    func resetAlbumArtwork() {
        track.artworkLoaded = false
        track.artworkURL = "radio_logo2.png"
        updateAlbumArtwork()
        stationDescLabel.isHidden = false
    }
    
    func updateAlbumArtwork() {
        track.artworkLoaded = false
        if track.artworkURL.range(of: "http") != nil {
            
            // Hide station description
            DispatchQueue.main.async(execute: {
                //self.albumImageView.image = nil
                self.stationDescLabel.isHidden = false
            })
            
            // Attempt to download album art from an API
            if let url = URL(string: track.artworkURL) {
                
                self.downloadTask = self.albumImageView.loadImageWithURL(url: url) { (image) in
                    
                    // Update track struct
                    self.track.artworkImage = image
                    self.track.artworkLoaded = true
                    
                    // Turn off network activity indicator
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        
                    // Animate artwork
                    self.albumImageView.animation = "wobble"
                    self.albumImageView.duration = 2
                    self.albumImageView.animate()
                    self.stationDescLabel.isHidden = true

                    // Update lockscreen
                    self.updateLockScreen()
                    
                    // Call delegate function that artwork updated
                    self.delegate?.artworkDidUpdate(track: self.track)
                }
            }
            
            // Hide the station description to make room for album art
            if track.artworkLoaded && !self.justBecameActive {
                self.stationDescLabel.isHidden = true
                self.justBecameActive = false
            }
            
        } else if track.artworkURL != "" {
            // Local artwork
            self.albumImageView.image = UIImage(named: track.artworkURL)
            track.artworkImage = albumImageView.image
            track.artworkLoaded = true
            
            // Call delegate function that artwork updated
            self.delegate?.artworkDidUpdate(track: self.track)
            
        } else {
            // No Station or API art found, use default art
            self.albumImageView.image = UIImage(named: "albumArt")
            track.artworkImage = albumImageView.image
        }
        
        // Force app to update display
        self.view.setNeedsDisplay()
    }

    // Call LastFM or iTunes API to get album art url
    
    func queryAlbumArt() {
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        // Construct either LastFM or iTunes API call URL
        let queryURL: String
        if useLastFM {
            queryURL = String(format: "http://ws.audioscrobbler.com/2.0/?method=track.getInfo&api_key=%@&artist=%@&track=%@&format=json", apiKey, track.artist, track.title)
        } else {
            queryURL = String(format: "https://itunes.apple.com/search?term=%@+%@&entity=song", track.artist, track.title)
        }
        
        let escapedURL = queryURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        
        // Query API
        DataManager.getTrackDataWithSuccess(queryURL: escapedURL!) { (data) in
            
            if kDebugLog {
                print("API SUCCESSFUL RETURN")
                print("url: \(escapedURL!)")
            }
            
            let json = JSON(data: data! as Data)
            
            if useLastFM {
                // Get Largest Sized LastFM Image
                if let imageArray = json["track"]["album"]["image"].array {
                    
                    let arrayCount = imageArray.count
                    let lastImage = imageArray[arrayCount - 1]
                    
                    if let artURL = lastImage["#text"].string {
                        
                        // Check for Default Last FM Image
                        if artURL.range(of: "/noimage/") != nil {
                            self.resetAlbumArtwork()
                            
                        } else {
                            // LastFM image found!
                            self.track.artworkURL = artURL
                            self.track.artworkLoaded = true
                            self.updateAlbumArtwork()
                        }
                        
                    } else {
                        self.resetAlbumArtwork()
                    }
                } else {
                    self.resetAlbumArtwork()
                }
            
            } else {
                // Use iTunes API. Images are 100px by 100px
                if let artURL = json["results"][0]["artworkUrl100"].string {
                    
                    if kDebugLog { print("iTunes artURL: \(artURL)") }
                    
                    self.track.artworkURL = artURL
                    self.track.artworkLoaded = true
                    self.updateAlbumArtwork()
                } else {
                    self.resetAlbumArtwork()
                }
            }
            
        }
    }
    
    //*****************************************************************
    // MARK: - Segue
    //*****************************************************************
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "InfoDetail" {
            let infoController = segue.destination as! InfoDetailViewController
            infoController.currentStation = currentStation
        }
    }
    
//    @IBAction func infoButtonPressed(_ sender: UIButton) {
//        performSegue(withIdentifier: "InfoDetail", sender: self)
//    }
    
    @IBAction func shareButtonPressed(_ sender: UIButton) {
        let textToShare = ["I'm listening to 104.7 via the God's Way Radio app! https://itunes.apple.com/us/app/gods-way-radio/id1063849401?mt=8"]
        let activityVC = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
        
        activityVC.excludedActivityTypes = [UIActivityType.airDrop, UIActivityType.addToReadingList]
        if UIDevice.current.userInterfaceIdiom == .pad {
            if  activityVC.responds(to: #selector(getter: UIViewController.popoverPresentationController))  {
                activityVC.popoverPresentationController?.sourceView = super.view
                /* to adjust pop-up position */
                //activityVC.popoverPresentationController?.sourceRect = CGRect(x: shareCircle.position.x,y: shareCircle.position.y, width: 0, height: 0)
            }
        }
        let currentViewController:UIViewController=UIApplication.shared.keyWindow!.rootViewController!
        
        currentViewController.present(activityVC, animated: true, completion: nil)
    }
    
    //*****************************************************************
    // MARK: - MPNowPlayingInfoCenter (Lock screen)
    //*****************************************************************
    
    func updateLockScreen() {
        
        // Update notification/lock screen
        let albumArtwork = MPMediaItemArtwork(image: UIImage(named: "radio_logo2.png")!)
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyArtist: artistLabel.text ?? "God's Way Radio",
            MPMediaItemPropertyTitle: songLabel.text ?? "104.7 WAYG-LP",
            MPMediaItemPropertyArtwork: albumArtwork
        ]
    }
    
    override func remoteControlReceived(with receivedEvent: UIEvent?) {
        super.remoteControlReceived(with: receivedEvent)
        
        if receivedEvent!.type == UIEventType.remoteControl {
            
            switch receivedEvent!.subtype {
            case .remoteControlPlay:
                playPressed()
            case .remoteControlPause:
                pausePressed()
            default:
                break
            }
        }
    }
    
    //*****************************************************************
    // MARK: - MetaData Updated Notification
    //*****************************************************************
//    @objc func metadataUpdated(n: NSNotification)
//    {
//        if(radioPlayer.timedMetadata != nil && radioPlayer.timedMetadata.count > 0)
//        {
//            startNowPlayingAnimation()
//
//            let firstMeta: MPTimedMetadata = radioPlayer.timedMetadata.first as! MPTimedMetadata
//            let metaData = firstMeta.value as! String
//
//            var stringParts = [String]()
//            if metaData.range(of: " - ") != nil {
//                stringParts = metaData.components(separatedBy: " - ")
//            } else {
//                stringParts = metaData.components(separatedBy: "-")
//            }
//
//            // Set artist & songvariables
//            let currentSongName = track.title
//            track.artist = stringParts[0]
//            track.title = stringParts[0]
//
//            if stringParts.count > 1 {
//                track.title = stringParts[1]
//            }
//
//            if track.artist == "" && track.title == "" {
//                track.artist = currentStation.stationDesc
//                track.title = currentStation.stationName
//            }
//
//            DispatchQueue.main.async(execute: {
//
//                if currentSongName != self.track.title {
//
//                    if kDebugLog {
//                        print("METADATA artist: \(self.track.artist) | title: \(self.track.title)")
//                    }
//
//                    // Update Labels
//                    self.artistLabel.text = self.track.artist
//                    self.songLabel.text = self.track.title
//                    self.updateUserActivityState(self.userActivity!)
//
//                    // songLabel animation
//                    self.songLabel.animation = "zoomIn"
//                    self.songLabel.duration = 1.5
//                    self.songLabel.damping = 1
//                    self.songLabel.animate()
//
//                    // Update Stations Screen
//                    self.delegate?.songMetaDataDidUpdate(track: self.track)
//
//                    // Query API for album art
//                    self.resetAlbumArtwork()
//                    self.queryAlbumArt()
//                    self.updateLockScreen()
//
//                }
//            })
//        }
//    }
    
    //*****************************************************************
    // MARK: - AVAudio Sesssion Interrupted
    //*****************************************************************
    
    // Example code on handling AVAudio interruptions (e.g. Phone calls)
    @objc func sessionInterrupted(notification: NSNotification) {
        if let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber{
            if let type = AVAudioSessionInterruptionType(rawValue: typeValue.uintValue){
                if type == .began {
                    print("interruption: began")
                    // Add your code here
                } else{
                    print("interruption: ended")
                    // Add your code here
                }
            }
        }
    }
    
    //*****************************************************************
    // MARK: - Handoff Functionality - GH
    //*****************************************************************
    
    func setupUserActivity() {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb ) //"com.graemeharrison.handoff.googlesearch" //NSUserActivityTypeBrowsingWeb
        userActivity = activity
        let url = "https://www.google.com/search?q=\(self.artistLabel.text!)+\(self.songLabel.text!)"
        let urlStr = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let searchURL : URL = URL(string: urlStr!)!
        activity.webpageURL = searchURL
        userActivity?.becomeCurrent()
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        let url = "https://www.google.com/search?q=\(self.artistLabel.text!)+\(self.songLabel.text!)"
        let urlStr = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let searchURL : URL = URL(string: urlStr!)!
        activity.webpageURL = searchURL
        super.updateUserActivityState(activity)
    }
}
