//
//  ContentModel.swift
//  Montreal's Sights
//
//  Created by Gordon Ng on 2022-07-06.
//

import Foundation
import CoreLocation

class ContentModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    var locationManager = CLLocationManager()
    
    @Published var restaurants = [Business]()
    @Published var sights = [Business]()
    @Published var authorizationState = CLAuthorizationStatus.notDetermined
    @Published var placemark: CLPlacemark?
    
    override init(){
        
        // Reference the init within the NSObject
        super.init()
        
        // Set content model as the delegate of the location manager
        locationManager.delegate = self
        
        
        
        // Start geolocating the user
        
    }
    
    func requestGeolocationPermission(){
        // Request permission from the user
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: Location Manager Delegate Methods
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        
        // Update the authorizationState property
        authorizationState = locationManager.authorizationStatus
    
        if locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse{
            // We have permission -> Start updating location
            locationManager.startUpdatingLocation()
            
        }
        else if locationManager.authorizationStatus == .denied{
            
            // No permission
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // Gives us the location of the user in coords, meters per second and time
        let userLocation = locations.first
        
        if userLocation != nil{
            
            // We have a location
            // Stop requesting the location after we get it once
            locationManager.stopUpdatingLocation()
            
            // Get the placemark of the user
            let geoCoder = CLGeocoder() // User friendly way of seeing location
            
            geoCoder.reverseGeocodeLocation(userLocation!){ (placemarks, error) in
                
                // Check that there aren't errors
                if error == nil && placemarks != nil{
                    
                    self.placemark = placemarks?.first
                }
                
            }
            
            // Send coordinates to Yelp API
            getBusinesses(category: Constants.sightsKey, location: userLocation!)
            getBusinesses(category: Constants.restaurantsKey, location: userLocation!)
        }
        
    }
    
    func getBusinesses(category:String, location:CLLocation){
        
        // Create URL
        /*
         let urlString = "https://api.yelp.com/v3/businesses/search?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&categories=\(category)&limit=6"
         
         let url = URL(string: urlString)
         
         */
        
        var urlComponents = URLComponents(string:Constants.apiUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "categories", value: category),
            URLQueryItem(name: "limit", value: "6")
        ]
        
        let url = urlComponents?.url
        
        if let url = url{
            // Create the URL Request
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)
            request.httpMethod = "GET"  //Endpoint type of GET from API docs
            
            request.addValue("Bearer \(Constants.apiKey)", forHTTPHeaderField: "Authorization")
            // Get URL Session
            let session = URLSession.shared
            
            // Create Data Task
            let dataTask = session.dataTask(with: request) { (data, response, error) in
                // Check that there isn't an error
                if error == nil{
                    
                    // Parse JSON
                    do{
                        let decoder = JSONDecoder()
                        let result = try decoder.decode(BusinessSearch.self, from: data!)
                        
                        // Sort businesses, result.businesses is unsorted
                        var businesses = result.businesses
                        businesses.sort{(b1,b2) -> Bool in
                            return b1.distance ?? 0 < b2.distance ?? 0
                        }
                        
                        // Call the get image function of the businesses
                        
                        for b in businesses{
                            b.getImageData()
                        }
                        
                        DispatchQueue.main.async{
                            // Assign results to the appropriate category, assigning things to a published property must be from main thread
                       
                            switch category{
                            case Constants.sightsKey:
                                self.sights = businesses
                            case Constants.restaurantsKey:
                                self.restaurants = businesses
                            default:
                                break
                            }
                        }
                        
                    }
                    catch{
                        print(error) // Error from datatask
                    }
                    
                    
                }
            }
            // Start the Data Task
            dataTask.resume()
        }
        
    }
}
