//
//  StationsViewController.swift
//  Swift Radio
//
//  Created by Matthew Fecher on 7/19/15.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation

var scheduleArray = [String]()
var scheduleJSLink = String()
class StationsViewController: UIViewController {
    var menuShowing = false
    //@IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sliderView: UIView!
    @IBOutlet weak var slideViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var contactButton: UIButton!
    @IBOutlet weak var stationNowPlayingButton: UIButton!
    @IBOutlet weak var nowPlayingAnimationImageView: UIImageView!
    @IBOutlet weak var liveButton: UIButton!
   
    var stations = [RadioStation]()
    var currentStation: RadioStation?
    var currentTrack: Track?
    var refreshControl: UIRefreshControl!
    var firstTime = true
    
    var searchedStations = [RadioStation]()
    var searchController : UISearchController!
    
    //*****************************************************************
    // MARK: - ViewDidLoad
    //*****************************************************************
    
    override func viewDidLoad() {
        super.viewDidLoad()
        liveButton.layer.cornerRadius = 10
        sliderView.layer.shadowOpacity = 1
        //contactButton.layer.cornerRadius = 10

        //performSegue(withIdentifier: "NowPlaying", sender: 0)
        // Register 'Nothing Found' cell xib
        //let cellNib = UINib(nibName: "NothingFoundCell", bundle: nil)
//        tableView.register(cellNib, forCellReuseIdentifier: "NothingFound")
        
        // preferredStatusBarStyle()
        
        // Load Data
        //loadStationsFromJSON()
        
        // Setup TableView
//        tableView.backgroundColor = UIColor.clear
//        tableView.backgroundView = nil
//        tableView.separatorStyle = UITableViewCellSeparatorStyle.none
//
        // Setup Pull to Refresh
        //setupPullToRefresh()
        
        // Create NowPlaying Animation
        createNowPlayingAnimation()
        
        // Set AVFoundation category, required for background audio
        var error: NSError?
        var success: Bool
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)))
            success = true
        } catch let error1 as NSError {
            error = error1
            success = false
        }
        if !success {
          if kDebugLog { print("Failed to set audio session category.  Error: \(String(describing: error))") }
        }
        
        // Set audioSession as active
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error2 as NSError {
            if kDebugLog { print("audioSession setActive error \(error2)") }
        }
        
        // Setup Search Bar
        //setupSearchController()
    }
    
    override func viewDidLayoutSubviews() {
        liveButton.layer.shadowOpacity = 0.7
        liveButton.layer.shadowOffset = CGSize(width: 0, height: 2)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.title = "God's Way Radio"
       
        
        // If a station has been selected, create "Now Playing" button to get back to current station
        if !firstTime {
            createNowPlayingBarButton()
        }else{
            //load schedule
            scheduleJSLink = loadScheduleLink()
            
        }
        
        // If a track is playing, display title & artist information and animation
        var title = "God's Way Radio"
        if playingRadio {
            title = "God's Way Radio" + " - Now Playing..."
            nowPlayingAnimationImageView.startAnimating()
        } else {
            title = "God's Way Radio" + " - Paused..."
            nowPlayingAnimationImageView.stopAnimating()
            nowPlayingAnimationImageView.image = UIImage(named: "NowPlayingBars")?.imageWithColor(tintColor: UIColor.red)
        }
        stationNowPlayingButton.setTitle(title, for: .normal)

        
    }

    //*****************************************************************
    // MARK: - Setup UI Elements
    //*****************************************************************
    
    func loadScheduleLink() -> String{
        let urlString = "https://drive.google.com/uc?export=download&id=1a5o3G_fKK799u3-JeR4sJZW467mkPxlQ"
        
        let url = URL(string: urlString)
        
        var webString : String = ""
        
        do {
            webString = try String(contentsOf: url!)
            return webString
        } catch {
            return "ERROR!!!!"
        }
    }
    
    func createNowPlayingAnimation() {
        nowPlayingAnimationImageView.animationImages = AnimationFrames.createFrames()
        nowPlayingAnimationImageView.animationDuration = 0.7
    }
    
    func createNowPlayingBarButton() {
        if self.navigationItem.rightBarButtonItem == nil {
            let btn = UIBarButtonItem(title: "", style: UIBarButtonItem.Style.plain, target: self, action:#selector(self.nowPlayingBarButtonPressed))
            btn.image = UIImage(named: "btn-nowPlaying")
            self.navigationItem.rightBarButtonItem = btn
        }
    }
    

    //*****************************************************************
    // MARK: - Actions
    //*****************************************************************
    
    @objc func nowPlayingBarButtonPressed() {
        menuShowing = true
        updateMenuIfNeeded()
        performSegue(withIdentifier: "NowPlaying", sender: self)
    }
    @IBAction func facebookButton(_ sender: Any) {
        menuShowing = true
        updateMenuIfNeeded()
            if let url = URL(string: "https://facebook.com/GodsWayRadio") {
                UIApplication.shared.open(url)
            
        }
        
    }
    @IBAction func twitterButton(_ sender: Any) {
        menuShowing = true
        updateMenuIfNeeded()
        if let url = URL(string: "https://twitter.com/godswayradio") {
            UIApplication.shared.open(url)
        }
    }
    @IBAction func youtubeButton(_ sender: Any) {
        menuShowing = true
        updateMenuIfNeeded()
        if let url = URL(string: "https://www.youtube.com/channel/UCHRWISEfus-AHDcizhlIUcA") {
            UIApplication.shared.open(url)
        }
    }
    @IBAction func instagramButton(_ sender: Any) {
        menuShowing = true
        updateMenuIfNeeded()
        if let url = URL(string: "https://www.instagram.com/godswayradio/") {
            UIApplication.shared.open(url)
        }
    }
    
    @IBAction func barButton(_ sender: UIBarButtonItem) {
        updateMenuIfNeeded()
    }
    
    @IBAction func nowPlayingPressed(_ sender: UIButton) {
        menuShowing = true
        updateMenuIfNeeded()
        performSegue(withIdentifier: "NowPlaying", sender: self)
        
    }
    
    func refresh(sender: AnyObject) {
        // Pull to Refresh
        stations.removeAll(keepingCapacity: false)
       // loadStationsFromJSON()
        
        // Wait 2 seconds then refresh screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.refreshControl.endRefreshing()
            self.view.setNeedsDisplay()
        }
    }
    
    func updateMenuIfNeeded(){
        if menuShowing{
            slideViewConstraint.constant = -240
            UIView.animate(withDuration: 0.3, animations: {
                self.view.layoutIfNeeded()
            })
        }else{
            print()
            slideViewConstraint.constant = 0
            UIView.animate(withDuration: 0.3, animations: {
                self.view.layoutIfNeeded()
            })
        }
        menuShowing = !menuShowing
    }
    //*****************************************************************
    // MARK: - Load Station Data
    //*****************************************************************
    

    //*****************************************************************
    // MARK: - Segue
    //*****************************************************************
    
    @IBAction func liveButton(_ sender: Any) {
        menuShowing = true
        updateMenuIfNeeded()
        performSegue(withIdentifier: "NowPlaying", sender: 0)
        
    }
  
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "NowPlaying" {
            
            self.title = ""
            firstTime = false
            
            let nowPlayingVC = segue.destination as! NowPlayingViewController
            nowPlayingVC.delegate = self
            
            if let indexPath = (sender as? NSIndexPath) {
                // User clicked on row, load/reset station
                if searchController.isActive {
                    currentStation = searchedStations[indexPath.row]
                } else {
                    currentStation = stations[indexPath.row]
                }
                nowPlayingVC.currentStation = currentStation
                nowPlayingVC.newStation = true
            
            } else {
                // User clicked on a now playing button
                if let currentTrack = currentTrack {
                    // Return to NowPlaying controller without reloading station
                    nowPlayingVC.track = currentTrack
                    nowPlayingVC.currentStation = currentStation
                    nowPlayingVC.newStation = false
                } else {
                    // Issue with track, reload station
                    nowPlayingVC.currentStation = currentStation
                    nowPlayingVC.newStation = true
                }
            }
        }
    }
}

//*****************************************************************
// MARK: - TableViewDataSource
//*****************************************************************



//*****************************************************************
// MARK: - NowPlayingViewControllerDelegate
//*****************************************************************

extension StationsViewController: NowPlayingViewControllerDelegate {
    
    func artworkDidUpdate(track: Track) {
        currentTrack?.artworkURL = track.artworkURL
        currentTrack?.artworkImage = track.artworkImage
    }
    
    func songMetaDataDidUpdate(track: Track) {
        currentTrack = track
        let title = currentStation!.stationName + ": " + currentTrack!.title + " - " + currentTrack!.artist + "..."
        stationNowPlayingButton.setTitle(title, for: .normal)
    }
    
    func trackPlayingToggled(track: Track) {
        currentTrack?.isPlaying = track.isPlaying
    }

}

//*****************************************************************
// MARK: - UISearchControllerDelegate
//*****************************************************************

extension StationsViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
    
        // Empty the searchedStations array
        searchedStations.removeAll(keepingCapacity: false)
    
        // Create a Predicate
        let searchPredicate = NSPredicate(format: "SELF.stationName CONTAINS[c] %@", searchController.searchBar.text!)
    
        // Create an NSArray with a Predicate
        let array = (self.stations as NSArray).filtered(using: searchPredicate)
    
        // Set the searchedStations with search result array
        searchedStations = array as! [RadioStation]
    
        // Reload the tableView
        //self.tableView.reloadData()
    }
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
