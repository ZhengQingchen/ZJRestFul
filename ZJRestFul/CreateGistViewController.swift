//
//  CreateGistViewController.swift
//  ZJRestFul
//
//  Created by mac on 15/11/20.
//  Copyright © 2015年 mac. All rights reserved.
//

import UIKit
import XLForm

class CreateGistViewController: XLFormViewController {
  
  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    initializeForm()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    initializeForm()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancelPressed:")
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Save, target: self, action: "savePressed:")
  }
  
  private func initializeForm(){
    
    let form = XLFormDescriptor(title: "Gist")
    
    //section 1
    
    let section1 = XLFormSectionDescriptor.formSection() as XLFormSectionDescriptor
    form.addFormSection(section1)
    
    let descriptionRow = XLFormRowDescriptor(tag: "description", rowType: XLFormRowDescriptorTypeText, title: "Description")
    descriptionRow.required = true
    section1.addFormRow(descriptionRow)
    
    let isPublicRow = XLFormRowDescriptor(tag: "isPublic", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: "Public?")
    isPublicRow.required = false
    section1.addFormRow(isPublicRow)
    
    // section 2
    
    let section2 = XLFormSectionDescriptor.formSectionWithTitle("File 1") as XLFormSectionDescriptor
    form.addFormSection(section2)
    
    let filenameRow = XLFormRowDescriptor(tag: "filename", rowType: XLFormRowDescriptorTypeText, title: "Filename")
    filenameRow.required = true
    section2.addFormRow(filenameRow)
    
    let fileContents = XLFormRowDescriptor(tag: "fileContents", rowType: XLFormRowDescriptorTypeTextView, title: "File Contents")
    fileContents.required = true
    section2.addFormRow(fileContents)
    
    self.form = form
  }
  
  // MARK: Actions
  
  func cancelPressed(button: UIBarButtonItem) {
    navigationController?.popViewControllerAnimated(true)
  }
  
  func savePressed(button: UIBarButtonItem) {
    let validationErrors: [NSError] = formValidationErrors() as! [NSError]
    
    guard validationErrors.count == 0 else {
      self.showFormValidationError(validationErrors.first)
      return
    }
    
    self.tableView.endEditing(true)
    
    let isPublic:Bool
    
    if let isPublicValue = form.formRowWithTag("isPublic")?.value as? Bool {
      isPublic = isPublicValue
    }else{
      isPublic = false
    }
    
    if let description = form.formRowWithTag("description")?.value as? String,
      filename = form.formRowWithTag("filename")?.value as? String,
      fileContents = form.formRowWithTag("fileContents")?.value as? String {
        var files: [File] = []
        if let file = File(aName: filename, aContents: fileContents) {
          files.append(file)
        }
        
        GitHubAPIManager.sharedInstance.createNewGist(description, isPublic: isPublic, files: files) {
          success, error in
          guard error == nil ,let successValue = success where successValue == true else {
            if let anError = error {
              print(anError)
            }
            let alertController = UIAlertController(title: "Could not create gist", message: "Sorrry, you gist couldn't be created. Maybe GitHub" +
              "is down or your don't have an internet connection", preferredStyle: .Alert)
            
            let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true , completion: nil)
            return
          }
          
          self.navigationController?.popViewControllerAnimated(true)
        }
    }
    
  }
}
















