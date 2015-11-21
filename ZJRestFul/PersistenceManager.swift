//
//  PersistenceManager.swift
//  ZJRestFul
//
//  Created by mac on 15/11/21.
//  Copyright © 2015年 mac. All rights reserved.
//

import Foundation

enum Path: String {
  case Public = "Public"
  case Starred = "Starred"
  case MyGists = "MyGists"
}

class PersistenceManager {
  
  class private func documentsDirectory() -> NSString {
    let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
    let documentDirectory = paths[0] as String
    return documentDirectory
  }
  
  class func saveArray<T:NSCoding> (arrayToSave: [T], path: Path) {
    let file = documentsDirectory().stringByAppendingPathComponent(path.rawValue)
    NSKeyedArchiver.archiveRootObject(arrayToSave, toFile: file)
  }
  
  class func loadArray<T:NSCoding> (path: Path) -> [T]? {
    let file = documentsDirectory().stringByAppendingPathComponent(path.rawValue)
    let result = NSKeyedUnarchiver.unarchiveObjectWithFile(file)
    return result as? [T]
  }
}