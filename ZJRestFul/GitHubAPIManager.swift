//
//  GitHubAPIManager.swift
//  ZJRestFul
//
//  Created by mac on 15/11/16.
//  Copyright © 2015年 mac. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import Locksmith
import ReachabilitySwift

class GitHubAPIManager {
  
  static let sharedInstance = GitHubAPIManager()
  static let ErrorDomain = "com.error.GitHubAPIManager"
  var alamofireManager: Manager
  
  var clientID: String = "7f401602f69b026ac92c"
  var clientSecret: String = "2be0a8c66eec023b29c7304c22e98bf82da5df8b"

  
  var OAuthToken: String? {
    set {
      if let valueToSave = newValue {
        do {
          try Locksmith.saveData(["token": valueToSave], forUserAccount: "github")
        }catch {
          let _ = try? Locksmith.deleteDataForUserAccount("github")
        }
        addSessionHeader("Authorization", value: "token \(valueToSave)")
      }else {
        let _ = try? Locksmith.deleteDataForUserAccount("github")
        removeSessionHeader("Authorization")
      }
    }
    get {
      if  let dictionary = Locksmith.loadDataForUserAccount("github"), token = dictionary["token"] as? String{
        return token
      }
      return nil
    }
  }
  
  var OauthTokenCompletionHandler: (NSError? -> Void)?
  
  init(){
    let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
    configuration.HTTPAdditionalHeaders = Manager.defaultHTTPHeaders
    alamofireManager = Manager(configuration: configuration)
    addSessionHeader("Accept", value: "application/vnd.github.v3+json")
    if hasOauthToken() {
      addSessionHeader("Authorization", value: "token \(OAuthToken!)")
    }
  }
  
  
  //MARK: - Oauth 2.0
  
  func hasOauthToken() -> Bool{
    if let token = self.OAuthToken {
      return !token.isEmpty
    }
    return false
  }
  
  
  func startOauth2Login() {
    var success = false
    
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.setBool(true, forKey: "loadingOAuthToken")
    
    let params = "client_id=\(clientID)&scope=gist&state=TEST_STATE"
    let baseURL = "https://github.com/login/oauth/authorize?"
    let authPath = baseURL + params
    
    
    guard let authURL: NSURL = NSURL(string: authPath) else {
      defaults.setBool(false, forKey: "loadingOAuthToken")
      if let completionHandler = OauthTokenCompletionHandler {
        let error = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1, userInfo: [
          NSLocalizedDescriptionKey: "Could not create an OAuth authorization URL",
          NSLocalizedRecoverySuggestionErrorKey: "Please retry you request."
          ])
        completionHandler(error)
      }
      return
    }
    
    do {
      guard try Reachability.reachabilityForInternetConnection().isReachable() == true else {
        if let completionHandler = OauthTokenCompletionHandler {
          let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet , userInfo: [
            NSLocalizedDescriptionKey: "Not internet connection",
            NSLocalizedRecoverySuggestionErrorKey: "Please retry you request."
            ])
          completionHandler(error)
        }
        return
      }
    }catch {
      print("Can not get internet status")
    }
   
    success =  UIApplication.sharedApplication().openURL(authURL)
    
    if !success {
      defaults.setBool(false, forKey: "loadingOAuthToken")
      if let completionHandler = OauthTokenCompletionHandler {
        let error = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1, userInfo: [
          NSLocalizedDescriptionKey: "Could not create an OAuth authorization URL",
          NSLocalizedRecoverySuggestionErrorKey: "Please retry you request."
          ])
        completionHandler(error)
      }
    }
  }
  
  func processOauthStep1Response(url: NSURL){
    let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
    var code: String?
    
    if let queryItems = components?.queryItems {
      for queryItem in queryItems {
        if queryItem.name.lowercaseString == "code" {
          code = queryItem.value
          break
        }
      }
    }
    if let receivedCode = code {
      swapAuthCodeForToken(receivedCode)
    }else {
      // no code in URL that we launch with
      let defaults = NSUserDefaults.standardUserDefaults()
      defaults.setBool(false, forKey: "loadingOAuthToken")
      
      if let completationHandler = OauthTokenCompletionHandler {
        let noCodeInResponseError = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1, userInfo: [
          NSLocalizedDescriptionKey: "Could not obain an Oauth code",
          NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"
          ])
        completationHandler(noCodeInResponseError)
      }
    }
  }
  
  func swapAuthCodeForToken(receivedCode: String) {
    let getTokenPath = "https://github.com/login/oauth/access_token"
    let tokenParams = ["client_id": clientID, "client_secret": clientSecret, "code": receivedCode]
    let jsonHeader = ["Accept": "application/json"]
    
    Alamofire.request(.POST, getTokenPath, parameters: tokenParams, encoding: .URL, headers: jsonHeader)
      .responseJSON(completionHandler: { (response) -> Void in
        
        guard response.result.error == nil else {
          let deflauts = NSUserDefaults.standardUserDefaults()
          deflauts.setBool(false, forKey: "loadingOAuthToken")
          
          if let completionHandler = self.OauthTokenCompletionHandler {
            completionHandler(response.result.error)
          }
          return
        }
        
        guard let value = response.result.value else {
          let deflaults = NSUserDefaults.standardUserDefaults()
          deflaults.setBool(false, forKey: "loadingOAuthToken")
          let error = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Count not obtain an OAuth token",
            NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"
            ])
          if let completionHandler = self.OauthTokenCompletionHandler {
            completionHandler(error)
          }
          return
        }
        
        let jsonResults = JSON(value)
        
        for (key,value) in jsonResults {
          switch key {
          case "access_token":
            self.OAuthToken = value.string
            print("Set token")
          case "scope" :
            //TODO: verify scope
            print("Set Scope")
          case "token_type" :
            //TODO: verify is bearer
            print("Check if bearer")
          default:
            print("got more than I expected from the OAuth token exchange")
            print(key)
          }
        }
        
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setBool(false, forKey: "loadingOAuthToken")
        
        if let completionHandler = self.OauthTokenCompletionHandler {
          print("completion OAuth.")
          print("self.hasOauthToken ? \(self.hasOauthToken())")
          if self.hasOauthToken() {
            completionHandler(nil)
          }else {
            let noOAuthError = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1, userInfo: [
              NSLocalizedDescriptionKey: "Could not obtain an OAuth token",
              NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"
              ])
            completionHandler(noOAuthError)
          }
        }
        
      })
  }
  
  // MARK: - Get Gists API
  
  
  func getGists(urlString: String, completionHandler: ((Result<[Gist], NSError>, String?) -> Void)) {
    alamofireManager.request(.GET, urlString)
      .validate()
      .responseArray { (response:Response<[Gist], NSError>) -> Void in
        
        debugPrint(response)
        guard response.result.error == nil else {
          completionHandler(response.result, nil)
          return
        }
        let next = self.getNextPageFromHeaders(response.response)
        completionHandler(response.result, next)
    }
  }
  
  func getPublicGists(pageToLoad: String? , completionHandler:((Result<[Gist], NSError>, String?) -> Void)) {
    if let urlString = pageToLoad {
      getGists(urlString, completionHandler: completionHandler)
    }else {
      getGists("https://api.github.com/gists/public", completionHandler: completionHandler)
    }
  }
  
  func getMystarredGist(pageToLoad: String? , completionHandler: ((Result<[Gist], NSError>, String?) -> Void))  {
    if let urlString =  pageToLoad {
      getGists(urlString, completionHandler: completionHandler)
    }else {
      getGists("https://api.github.com/gists/starred", completionHandler: completionHandler)
    }
  }
  
  func getMyGists(pageToLoad: String?, completionHandler: ((Result<[Gist], NSError>, String?) -> Void)) {
    if let urlString = pageToLoad {
      getGists(urlString, completionHandler: completionHandler)
    }else {
      getGists("https://api.github.com/gists", completionHandler: completionHandler)
    }
  }
  
  
  //MARK: Starring / unStarring / star status
  
  func isGistStarred(gistId: String, completionHandler: (Bool?, NSError?) -> Void) {
    let urlString = "https://api.github.com/gists/\(gistId)/star"
    alamofireManager.request(.GET, urlString)
      .validate(statusCode: [204])
      .response { (request, response, data, error) -> Void in
        if let error = error {
          print(error)
          if response?.statusCode == 404 {
            completionHandler(false, nil)
            return
          }
          completionHandler(nil, error)
          return
        }
        completionHandler(true, nil)
    }
  }
  
  func starGist(gistId: String, completionHandler: (ErrorType?) -> Void){
    let urlString = "https://api.github.com/gists/\(gistId)/star"
    alamofireManager.request(.PUT, urlString)
      .validate()
      .response { (request , response, data, error) -> Void in
        if let anError = error {
          print(anError)
          return
        }
        completionHandler(error)
    }
  }
  
  func unstarGist(gistId: String, completionHandler: (ErrorType?) -> Void) {
    let urlString = "https://api.github.com/gists/\(gistId)/star"
    alamofireManager.request(.DELETE, urlString)
      .validate()
      .response { (request, response, data , error) -> Void in
        if let anError = error {
          print(anError)
          return
        }
        completionHandler(error)
    }
  }
  
  //MARK: delete Gist
  
  func deleteGist(gistId: String, completionHandler: (ErrorType?) -> Void) {
    let urlString = "https://api.github.com/gists/\(gistId)"
    alamofireManager.request(.DELETE, urlString)
      .validate()
      .response { (request, response, data, error) -> Void in
        if let anError = error {
          print(anError)
          return
        }
        self.clearCache()
        completionHandler(error)
    }
  }
  
  func createNewGist(description: String, isPublic: Bool, files : [File], completionHandler: (Bool?, NSError?) -> Void) {
    let publicString: String
    if isPublic {
      publicString = "true"
    }else{
      publicString = "false"
    }
    
    var filesDictionary = [String: AnyObject]()
    for file in files {
      if let name = file.fileName, contents = file.contents {
        filesDictionary[name] = ["content": contents]
      }
    }
    let parameters: [String: AnyObject] = [
        "description": description,
        "isPublic": publicString,
        "files": filesDictionary
    ]
    
    let urlString = "https://api.github.com/gists"
    
    alamofireManager.request(.POST, urlString, parameters: parameters, encoding: .JSON)
      .validate()
      .response { (request, response, data, error) -> Void in
        if let anError = error {
          print(anError)
          completionHandler(false, nil)
          return
        }
        self.clearCache()
        completionHandler(true, nil)
    }
  }
  
  // MARK: Helper
  
  private func addSessionHeader(key: String, value: String) {
    var headers: [NSObject : AnyObject]
    
    if let existingHeaders = alamofireManager.session.configuration.HTTPAdditionalHeaders  {
      headers = existingHeaders
    }else {
      headers = Manager.defaultHTTPHeaders
    }
    
    headers[key] = value
    let config = alamofireManager.session.configuration
    config.HTTPAdditionalHeaders = headers
    
    alamofireManager = Alamofire.Manager(configuration: config)
  }
  
  private func removeSessionHeader(key: String) {
    let config = alamofireManager.session.configuration
    
    if var headers = config.HTTPAdditionalHeaders {
      headers.removeValueForKey(key)
      config.HTTPAdditionalHeaders = headers
      alamofireManager = Alamofire.Manager(configuration: config)
    }
  }
  
  
  private func getNextPageFromHeaders(response: NSHTTPURLResponse?) -> String? {
    if let linkHeader = response?.allHeaderFields["Link"] as? String {
      let components = linkHeader.characters.split{ $0 == ","}.map{ String($0)}
      for item in components {
        if let _ = item.rangeOfString("rel=\"next\"", options: []) {
          let rangeOfPaddedURL = item.rangeOfString("<(.*)>;", options: .RegularExpressionSearch)
          if let range = rangeOfPaddedURL {
            let nextURL = item.substringWithRange(range)
            let startIndex = nextURL.startIndex.advancedBy(1)  // 去头
            let endIndex = nextURL.endIndex.advancedBy(-2) // 去尾部
            let urlRange = startIndex..<endIndex
            return nextURL.substringWithRange(urlRange)
          }
        }
      }
    }
    return nil
  }
  
  func clearCache() {
    let cache = NSURLCache.sharedURLCache()
    cache.removeAllCachedResponses()
  }
}

