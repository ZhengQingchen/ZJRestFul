//
//  File.swift
//  ZJRestFul
//
//  Created by mac on 15/11/18.
//  Copyright © 2015年 mac. All rights reserved.
//

import Foundation
import SwiftyJSON

class File: NSObject, NSCoding, ResponseJSONObjectSerializalbe {
  var fileName: String?
  var raw_url: String?
  var contents: String?
  
  required init?(json: JSON){
    self.fileName = json["filename"].string
    self.raw_url = json["raw_url"].string
  }
  
  init?(aName:String?, aContents: String?) {
    self.fileName = aName
    self.contents = aContents
  }
  
  @objc required convenience init?(coder aDecoder: NSCoder) {
    let filename = aDecoder.decodeObjectForKey("filename") as? String
    let contents = aDecoder.decodeObjectForKey("contents") as? String
    
    self.init(aName: filename, aContents: contents)
    self.raw_url = aDecoder.decodeObjectForKey("raw_url") as? String
  }
  
  @objc func encodeWithCoder(aCoder: NSCoder) {
    aCoder.encodeObject(self.fileName, forKey: "filename")
    aCoder.encodeObject(self.raw_url, forKey: "raw_url")
    aCoder.encodeObject(self.contents, forKey: "contents")
  }
}