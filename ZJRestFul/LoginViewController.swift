//
//  LoginViewController.swift
//  ZJRestFul
//
//  Created by mac on 15/11/18.
//  Copyright © 2015年 mac. All rights reserved.
//

import UIKit

protocol LoginViewDelegate: class {
  func didTapLoginButton()
}

class LoginViewController: UIViewController {
  
  weak var delegate: LoginViewDelegate?
  
  @IBAction func tappedLoginButton(){
    //TODO: implement
    if let delegate = self.delegate {
      delegate.didTapLoginButton()
    }
  }
  
  @IBAction func dismissSelf(){
    let defaults = NSUserDefaults.standardUserDefaults()
    if !defaults.boolForKey("loadingOauthToken") {
      dismissViewControllerAnimated(true, completion: nil)
    }
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
//    dismissSelf()
  }
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

}
