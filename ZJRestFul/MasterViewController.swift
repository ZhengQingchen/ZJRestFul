//
//  MasterViewController.swift
//  ZJRestFul
//
//  Created by mac on 15/11/16.
//  Copyright © 2015年 mac. All rights reserved.
//

import UIKit
import Alamofire
import PINRemoteImage
import BRYXBanner

class MasterViewController: UITableViewController {
  
  var detailViewController: DetailViewController? = nil
  var gists = [Gist]()
  var nextPageURLString: String?
  var isLoading = false
  var dateFormatter = NSDateFormatter()
  var notConnectedBanner: Banner?
  
  @IBOutlet weak var gistSegmentedControl: UISegmentedControl!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
    if let split = self.splitViewController {
      let controllers = split.viewControllers
      self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
    }
    let defaults = NSUserDefaults.standardUserDefaults()
    if !defaults.boolForKey("loadingOauthToken") {
      loadInitialData()
    }
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    if refreshControl == nil {
      refreshControl = UIRefreshControl()
      refreshControl?.addTarget(self, action: "refresh:", forControlEvents: .ValueChanged)
      dateFormatter.dateStyle = .ShortStyle
      dateFormatter.timeStyle = .LongStyle
    }
    
    let defaults = NSUserDefaults.standardUserDefaults()
    if gistSegmentedControl.selectedSegmentIndex == 2 {
      if !defaults.boolForKey("loadingOAuthToken") {
        loadInitialData()
      }
    }
  }
  
  override func viewWillDisappear(animated: Bool) {
    super.viewWillAppear(animated)
    if let existingBanner = notConnectedBanner {
      existingBanner.dismiss()
    }
  }
  
  //ACTION;
  @IBAction func segmentedControlValueChanged(sender: UISegmentedControl) {
    
    if gistSegmentedControl.selectedSegmentIndex == 2 {
      navigationItem.leftBarButtonItem = editButtonItem()
      let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
      self.navigationItem.rightBarButtonItem = addButton
    }else {
      navigationItem.leftBarButtonItem = nil
    }
    
    nextPageURLString = nil
    loadGists()
  }
  
  func loadInitialData(){
    isLoading = true
    
    GitHubAPIManager.sharedInstance.OauthTokenCompletionHandler = { error in
      
      if let receivedError = error {
        print(receivedError)
        self.isLoading = false
        //TODO: error Handle 
        // something go wrong, try again
        self.showOauthLoginView()
      }else {
        self.loadGists()
      }
    }
    
    if !GitHubAPIManager.sharedInstance.hasOauthToken() {
      showOauthLoginView()
    }else {
      
      loadGists()
    }
  }
  
  func showOauthLoginView(){
    isLoading = true
    GitHubAPIManager.sharedInstance.OauthTokenCompletionHandler = { error in
      if let receivedError = error {
        print(receivedError)
        self.isLoading = false
        
        //Error handle
        self.showOauthLoginView()
      }else {
        self.loadGists()
      }
    }
    if let loginVC = storyboard?.instantiateViewControllerWithIdentifier("LoginViewController") as? LoginViewController {
      loginVC.delegate = self
      presentViewController(loginVC, animated: true, completion: nil)
    }
  }
  
  override func viewWillAppear(animated: Bool) {
    self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
    super.viewWillAppear(animated)
  }
  
  
  
  func refresh(sender: AnyObject) {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.setBool(false, forKey: "loadingOAuthToken")
    nextPageURLString = nil
    loadInitialData()
  }
  
  func loadGists(urlToLoad: String? = nil){
    isLoading = true
    let completionHandler:(result:Result<[Gist], NSError>, String?) -> Void = { (result:Result<[Gist], NSError>, nextPage) -> Void in
      
      if self.refreshControl != nil  && self.refreshControl!.refreshing {
        self.refreshControl?.endRefreshing()
      }
      
      guard result.error == nil else {
        
        if let error = result.error {
          if error.domain == NSURLErrorDomain && error.code == NSURLErrorUserAuthenticationRequired {
            self.showOauthLoginView()
          }else if error.code == NSURLErrorNotConnectedToInternet {
            let path:Path
            if self.gistSegmentedControl.selectedSegmentIndex == 0 {
              path = .Public
            }else if self.gistSegmentedControl.selectedSegmentIndex == 1{
              path = .Starred
            }else {
              path = .MyGists
            }
            if let archived:[Gist] = PersistenceManager.loadArray(path) {
              self.gists = archived
              self.tableView.reloadData()
            }else {
              self.gists = []
            }
            
            if let existingBanner = self.notConnectedBanner {
              existingBanner.dismiss()
            }
            self.notConnectedBanner = Banner(title: "Not Internet Connection", subtitle: "Could not load gists." +
              "Try again when you are connected to the Internet", image: nil, backgroundColor: UIColor.redColor())
            self.notConnectedBanner?.dismissesOnSwipe = true
            self.notConnectedBanner?.adjustsStatusBarStyle = true
            self.notConnectedBanner?.show(duration: nil)
          }
        }
        return
      }
      
      if let fetchedGists = result.value {
        if self.nextPageURLString != nil {
          self.gists += fetchedGists
        }else {
          self.gists = fetchedGists
        }
        let path: Path
        if self.gistSegmentedControl.selectedSegmentIndex == 0 {
          path = .Public
        }else if self.gistSegmentedControl.selectedSegmentIndex == 1{
          path = .Starred
        }else {
          path = .MyGists
        }
        PersistenceManager.saveArray(self.gists, path: path)
      }
      
      
      
      //Update "Last updated" title for refresh control
      
      let now = NSDate()
      let updateString = "Last Updated at " + self.dateFormatter.stringFromDate(now)
      self.refreshControl?.attributedTitle = NSAttributedString(string: updateString)
      
      self.tableView.reloadData()
      self.isLoading = false
      self.nextPageURLString = nextPage
      
    }
    
    switch gistSegmentedControl.selectedSegmentIndex {
    case 0:
      GitHubAPIManager.sharedInstance.getPublicGists(urlToLoad, completionHandler: completionHandler)
    case 1:
      GitHubAPIManager.sharedInstance.getMystarredGist(urlToLoad, completionHandler: completionHandler)
    case 2:
      GitHubAPIManager.sharedInstance.getMyGists(urlToLoad, completionHandler: completionHandler)
    default:
      print("Got unexpected index for gistSegmentedControl.selectedSegmentIndex")
    }
  }
  
  func insertNewObject(sender: AnyObject) {
    
    let creatVC = CreateGistViewController(nibName: nil, bundle: nil)
    navigationController?.pushViewController(creatVC, animated: true)
  }
  

  
  // MARK: - Segues
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "showDetail" {
      if let indexPath = self.tableView.indexPathForSelectedRow {
        let object = gists[indexPath.row]
        let controller = (segue.destinationViewController as! UINavigationController).topViewController as! DetailViewController
        controller.gist = object
        controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
        controller.navigationItem.leftItemsSupplementBackButton = true
      }
    }
  }
  
  // MARK: - Table View
  
  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return gists.count
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    
    let gist = gists[indexPath.row]
    cell.textLabel!.text = gist.gistDescription
    cell.detailTextLabel!.text = gist.ownerLogin
    if let urlString = gist.ownerAvatarURL, url = NSURL(string: urlString) {
      cell.imageView?.pin_setImageFromURL(url, placeholderImage: UIImage(named: "placeholder.png"))
    }else {
      cell.imageView?.image = UIImage(named: "placeholder.png")
    }
    
    // See if we need to load more gists 
    
    let rowsToLoadFromBottom = 5
    let rowsLoaded = gists.count
    
    if let nextPage = nextPageURLString {
      if indexPath.row >= (rowsLoaded - rowsToLoadFromBottom) && !isLoading {
        self.loadGists(nextPage)
      }
    }
    
    return cell
  }
  
  override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // Return false if you do not want the specified item to be editable.
    return gistSegmentedControl.selectedSegmentIndex == 2
  }
  
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
      let gistToDelete = gists.removeAtIndex(indexPath.row)
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
      
      //delete from api
      if let id = gists[indexPath.row].id {
        GitHubAPIManager.sharedInstance.deleteGist(id, completionHandler: { (error) -> Void in
          print(error)
          if let _ = error {
            self.gists.insert(gistToDelete, atIndex: indexPath.row)
            tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
            
            let alertController = UIAlertController(title: "Could not delete gist",
              message: "Sorry, your gist couldn't be deleted. Maybe GitHub is "
              + "down or you don't have an internet connection.", preferredStyle: .Alert)
            let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
            alertController.addAction(okAction)
            
            self.presentViewController(alertController, animated: true, completion: nil)
          }
        })
      }
      
    } else if editingStyle == .Insert {
      // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }
  }
}

extension MasterViewController: LoginViewDelegate {
  func didTapLoginButton() {
    dismissViewControllerAnimated(false, completion: nil)
    GitHubAPIManager.sharedInstance.startOauth2Login()
  }
}

