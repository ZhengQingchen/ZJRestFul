//
//  DetailViewController.swift
//  ZJRestFul
//
//  Created by mac on 15/11/16.
//  Copyright © 2015年 mac. All rights reserved.
//

import UIKit
import WebKit
import BRYXBanner

class DetailViewController: UIViewController {

  @IBOutlet weak var tableView: UITableView!
  var isStarred: Bool?
  var notConnectedBanner: Banner?

  var gist: Gist? {
    didSet {
        // Update the view.
        self.configureView()
    }
  }

  func configureView() {
    // Update the user interface for the detail item.
    if let _ = gist {
      fetchStarredStatus()
      if let detailsView = tableView {
        detailsView.reloadData()
      }
    }
  }

  func fetchStarredStatus() {
    if let gistId = gist?.id {
      GitHubAPIManager.sharedInstance.isGistStarred(gistId, completionHandler: { (status, error) -> Void in
        
        if let error = error {
          print(error)
          if error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet {
            if let existingBanner = self.notConnectedBanner {
              existingBanner.dismiss()
            }
            self.notConnectedBanner = Banner(title: "No Internet Connection", subtitle: "Can not display starred status" +
              " Try again when you're connected to internet", image: nil, backgroundColor: UIColor.orangeColor())
            self.notConnectedBanner?.dismissesOnSwipe = true
            self.notConnectedBanner?.show()
          }
        }
        
        if self.isStarred == nil && status != nil {
          self.isStarred = status
          self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 2, inSection: 0)], withRowAnimation: .Automatic)
        }
        
      })
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.configureView()
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillAppear(animated)
    if let existingBanner = notConnectedBanner {
      existingBanner.dismiss()
    }
  }
  
  // API CALL
  
  func startThisGist(){
    if let gistId = gist?.id {
      GitHubAPIManager.sharedInstance.starGist(gistId) {
        error in
        if let anError = error {
          print(anError)
          let alertController = UIAlertController(title: "Could not star gist", message: "Sorry, you gist couldn't starred. Maybe GitHub is " +
            "down or you dont't have an internet connection", preferredStyle: .Alert)
          alertController.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
          self.presentViewController(alertController, animated: true, completion: nil)
        }else {
          self.isStarred = true
          self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 2, inSection: 0)], withRowAnimation: .Automatic)
        }
      }
    }
  }
  
  func unstarThisGist(){
    if let gistId = gist?.id {
      GitHubAPIManager.sharedInstance.unstarGist(gistId){
        error in
        if let anError = error {
          print(anError)
          let alertController = UIAlertController(title: "Could not star gist", message: "Sorry, you gist couldn't unstarred. Maybe GitHub is " +
            "down or you dont't have an internet connection", preferredStyle: .Alert)
          alertController.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
          self.presentViewController(alertController, animated: true, completion: nil)
        }else {
          self.isStarred = false
          self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 2, inSection: 0)], withRowAnimation: .Automatic)
        }
      }
    }
  }
}

extension DetailViewController: UITableViewDataSource {
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 2
  }
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      if let _ = isStarred {
        return 3
      }
      return 2
    }else {
      return gist?.files?.count ?? 0
    }
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    if indexPath.section == 0 {
      if indexPath.row == 0 {
        cell.textLabel?.text = gist?.gistDescription
      }else if indexPath.row == 1 {
        cell.textLabel?.text = gist?.ownerLogin
      }else if indexPath.row == 2 {
        if let isStarred = isStarred {
          cell.textLabel?.text = isStarred ? "Unstar" : "Star"
        }
      }
    }else {
      if let file = gist?.files?[indexPath.row] {
        cell.textLabel?.text = file.fileName
      }
    }
    return cell
  }
  
  func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if section == 0 {
      return "About"
    }
    return "Files"
  }
}


extension DetailViewController: UITableViewDelegate {
  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    if indexPath.section == 0 {
      if indexPath.row == 2 {
        if let starred = isStarred {
          if starred {
            unstarThisGist()
          }else
          {
            startThisGist()
          }
        }
      }
    }
    
    if indexPath.section == 1 {
      if let file = gist?.files?[indexPath.row], urlString = file.raw_url, url = NSURL(string: urlString) {
        
        let webView = WKWebView()
        let webViewWrapperVC = UIViewController()
        webViewWrapperVC.view = webView
        webViewWrapperVC.title = file.fileName
        
        let request = NSURLRequest(URL: url)
        webView.loadRequest(request)
        
        navigationController?.pushViewController(webViewWrapperVC, animated: true)
      }
    }
  }
  
}
