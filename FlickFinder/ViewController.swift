//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        // FIX: As of Swift 2.2, using strings for selectors has been deprecated. Instead, #selector(methodName) should be used.
        subscribeToNotification(notification: NSNotification.Name.UIKeyboardWillShow.rawValue, selector: #selector(keyboardWillShow))
        subscribeToNotification(notification: NSNotification.Name.UIKeyboardWillHide.rawValue, selector: #selector(keyboardWillHide))
        subscribeToNotification(notification: NSNotification.Name.UIKeyboardDidShow.rawValue, selector: #selector(keyboardDidShow))
        subscribeToNotification(notification: NSNotification.Name.UIKeyboardDidHide.rawValue, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
	@IBAction func searchByPhrase(_ sender: AnyObject) {
		userDidTapView(sender: self)
		setUIEnabled(enabled: false)
		
		if !phraseTextField.text!.isEmpty {
			photoTitleLabel.text = "Searching..."
			
			let methodParameters: [String: String?] = [
				Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
				Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
				Constants.FlickrParameterKeys.Text: phraseTextField.text,
				Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
				Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
				Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
				Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
			]
			
			displayImageFromFlickrBySearch(methodParameters: methodParameters as [String : AnyObject])
		}
		else {
			setUIEnabled(enabled: true)
			photoTitleLabel.text = "Phrase Empty."
		}
	}
	@IBAction func searchByLatLong(_ sender: AnyObject) {
		userDidTapView(sender: self)
		setUIEnabled(enabled: false)
		
		if isTextFieldValid(textField: latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(textField: longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
			photoTitleLabel.text = "Searching..."
			
			let methodParameters: [String: String?] = [
				Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
				Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
				Constants.FlickrParameterKeys.BoundingBox: bboxString(),
				Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
				Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
				Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
				Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
			]
			
			displayImageFromFlickrBySearch(methodParameters: methodParameters as [String : AnyObject])
		}
		else {
			setUIEnabled(enabled: true)
			photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
		}
	}

	private func bboxString()-> String {
		
		guard let latitude = Double(latitudeTextField.text!),
		let longitude = Double(longitudeTextField.text!) else {
			print("Latitude value not found.")
			return "0,0,0,0"
		}
		
		let minLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
		let minLong = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
		let maxLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
		let maxLong = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
		
		return "\(minLong),\(minLat),\(maxLong),\(maxLat)"
	}
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(methodParameters: [String:AnyObject]) {
        
        let url = flickrURLFromParameters(parameters: methodParameters)
        
		let session = URLSession.shared
		let request = URLRequest.init(url: url as URL)
		
		let task = session.dataTask(with: request) { (data, response, error) in

			// if an error occurs, print it and re-enable the UI
			func displayError(_ error: String) {
				print(error)
				print("URL at time of error: \(url)")
				performUIUpdatesOnMain {
					self.photoTitleLabel.text = "No image returned."
					self.photoImageView.image = nil
				}
			}
			
			/* GUARD: Was there an error? */
			guard (error == nil) else {
				displayError("There was an error with your request: \(error)")
				return
			}
			
			/* GUARD: Did we get a successful 2XX response? */
			guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
				displayError("Your request returned a status code other than 2xx!")
				return
			}
			
			/* GUARD: Was there any data returned? */
			guard let data = data else {
				displayError("No data was returned by the request!")
				return
			}
			
			// parse the data
			let parsedResult: [String:AnyObject]!
			do {
				parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
			} catch {
				displayError("Could not parse the data as JSON: '\(data)'")
				return
			}
			
			/* GUARD: Did Flickr return an error (stat != ok)? */
			guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
				displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
				return
			}
			
			/* GUARD: Are the "photos" and "photo" keys in our result? */
			guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject], let totalPages = photosDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
				displayError("Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' and '\(Constants.FlickrResponseKeys.Pages)' in \(parsedResult)")
				return
			}
			
			let pages = min(totalPages, 40)
			let randomPageIndex = Int(arc4random_uniform(UInt32(pages)))
			print(pages)
			print(randomPageIndex)
			/*
			// select a random photo
			let randomPhotoIndex = Int(arc4random_uniform(UInt32(photoArray.count)))
			let photoDictionary = photoArray[randomPhotoIndex] as [String:AnyObject]
			let photoTitle = photoDictionary[Constants.FlickrResponseKeys.Title] as? String
			
			/* GUARD: Does our photo have a key for 'url_m'? */
			guard let imageUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String else {
				displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(photoDictionary)")
				return
			}
			
			// if an image exists at the url, set the image and title
			let imageURL = URL(string: imageUrlString)
			if let imageData = try? Data(contentsOf: imageURL!) {
				performUIUpdatesOnMain {
					self.setUIEnabled(enabled: true)
					self.photoImageView.image = UIImage(data: imageData)
					self.photoTitleLabel.text = photoTitle ?? "(Untitled)"
				}
			} else {
				displayError("Image does not exist at \(imageURL)")
			}

			*/
		}
		
		task.resume()
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(parameters: [String:AnyObject]) -> URL {
        
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = NSURLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem as URLQueryItem)
        }
        
        return components.url!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
	
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification: notification)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification: notification)
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(notification: NSNotification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(sender: AnyObject) {
        resignIfFirstResponder(textField: phraseTextField)
        resignIfFirstResponder(textField: latitudeTextField)
        resignIfFirstResponder(textField: longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    func isTextFieldValid(textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!), !textField.text!.isEmpty {
            return isValueInRange(value: value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    private func isValueInRange(value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

extension ViewController {
    
    func setUIEnabled(enabled: Bool) {
        photoTitleLabel.isEnabled = enabled
        phraseTextField.isEnabled = enabled
        latitudeTextField.isEnabled = enabled
        longitudeTextField.isEnabled = enabled
        phraseSearchButton.isEnabled = enabled
        latLonSearchButton.isEnabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

extension ViewController {
    
    func subscribeToNotification(notification: String, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: NSNotification.Name(rawValue: notification), object: nil)
    }
    
	func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
