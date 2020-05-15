//: A MapKit based Playground
import UIKit
import MapKit
import PlaygroundSupport

// struct to organize the data on testing sites.
struct TestingSite {
    var name: String
    var phone: String
    var streetAddress: String
    var city: String
    var zip: String
    var description: String // info about the site
}

// set up the custom font that I used
let cfURL = Bundle.main.url(forResource: "DIN-Regular", withExtension: "ttf")! as CFURL
CTFontManagerRegisterFontsForURL(cfURL, CTFontManagerScope.process, nil)

// the main view controller for the playground
class MainViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    // for the UIPicker
    var toolBar = UIToolbar()
    var picker  = UIPickerView()
    
    // array that stores values of the testing site data.
    var testingSites: [TestingSite] = [TestingSite]()
    var testingPins: [MKPointAnnotation] = [MKPointAnnotation]()
    // current states that the API supports.
    var statesList = ["California", "New York", "Washington", "New Jersey", "Florida"]
    var selectedState = "california" // currently picked state (based on the UIPicker)
    
    
    var mainLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 225, y: 30, width: 400, height: 80))
        label.text = "Covid-19 Testing Site Finder"
        label.font = UIFont.regularFont(size: 30)
        label.textAlignment = .center
        label.textColor = UIColor.init(white: 0.95, alpha: 1)
        return label
    }()
    
    // footer label on the bottom
    var footerLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 0 , y: 850, width: UIScreen.main.bounds.width, height: 40))
        label.text = "Created by Rastaar Haghi as part of WWDC20 Swift Student Challenge"
        label.font = UIFont.regularFont(size: 14)
        label.textAlignment = .center
        label.textColor = UIColor.init(white: 0.95, alpha: 1)
        return label
    }()
    
    @IBOutlet var searchButton: UIButton! = {
        let button = UIButton(frame: CGRect(x: 275, y: 175, width: 300, height: 50))
        button.setTitle("Select a State to Search", for: .normal)
        button.titleLabel!.font = UIFont.regularFont(size: 24)
        button.titleLabel?.textAlignment = .center
        button.addTarget(self, action: #selector(createPickerView), for: .touchUpInside)
        button.backgroundColor = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1)
        button.layer.cornerRadius = 15
        return button
    }()
    
    // map view initializer for the view.
    let mapView: MKMapView! = {
        let map = MKMapView(frame: CGRect(x: 20, y: UIScreen.main.bounds.maxY / 3, width: 960, height: 500 ))
        map.showsUserLocation = true
        map.showsScale = true
        map.showsBuildings = true
        map.backgroundColor = .black
        map.isZoomEnabled = true
        return map
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1)
        // add the subviews to the view controller
        view.addSubview(mapView)
        view.addSubview(searchButton)
        view.addSubview(mainLabel)
        view.addSubview(footerLabel)
        self.picker.delegate = self
        self.picker.dataSource = self
        // set the view to dark if available.
        overrideUserInterfaceStyle = .dark
        // update the map to default of california
        updateMap(currentState: selectedState)
    }

    @objc
    private func updateMap(currentState: String) {
        print("Updating map to the state: ", selectedState)
        testingSites.removeAll()
        print("Removed all testing sites from array")

        self.mapView.removeAnnotations(testingPins)
        print("Removed all pins from map view")
        
        testingPins.removeAll()
        print("Removed all testing pins from array")
        
        var stateString: String = "california" // default value
        
        if currentState == "California" {
            stateString = "california"
        } else if currentState == "New York" {
            stateString = "new-york"
        } else if currentState == "Washington" {
            stateString = "washington"
        } else if currentState == "New Jersey" {
            stateString = "new-jersey"
        } else if currentState == "Florida" {
            stateString = "florida"
        }
        // make the search for the testing sites of the selected states.
        getTestingSites(stateName: stateString)
    }
    
    // function that fetches testing sites for a given state.
    func getTestingSites(stateName: String) {
        let request = NSMutableURLRequest(url: NSURL(string: "https://covid-19-testing.github.io/locations/" + stateName + "/complete.json")! as URL,
             cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        request.httpMethod = "GET"
        // make get request.
        let task = URLSession.shared.dataTask(with: request as URLRequest){
            data, response, error in
            // if there was an error fetching the data, return
            if error != nil {
                print("Error in gathering covid data")
                print(error!)
                return
            }

            var err: NSError?
            do
            {
                // convert data returned into JSON
                let sitesJSON = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as! [[String:Any]]
                // parse the json for the details we care about!
                for site in sitesJSON {
                    let name = site["name"] as! String
                    let description = site["description"] as! String
                    
                    guard let phones = site["phones"] as? Array<Any> else { return }
                        guard let phoneZero = phones[0] as? [String: String] else { return }
                        guard let phoneNum = phoneZero["number"] else { return }

                    guard let address = site["physical_address"] as? Array<Any> else { return }
                        guard let address0 = address[0] as? [String: String] else { return }
                        guard let streetAddress = address0["address_1"] else { return }
                        guard let cityAddress = address0["city"] else { return }
                        guard let postalCode = address0["postal_code"] else { return }
                    // format as testingSite class.
                    let testingSite: TestingSite = TestingSite(name: name, phone: phoneNum, streetAddress: streetAddress, city: cityAddress, zip: postalCode, description: description)
                    self.testingSites.append(testingSite)
                }
                // now push those testing sites onto the mapview.
                self.loadSitesOnMap()
            }
            catch let error as NSError {
                err = error
                print(err!)
            }
        }
        task.resume()
    }

    // loads sites onto map
    func loadSitesOnMap() {
        print("Loading the sites on the map")
        print("Number of testing sites to add: ", testingSites.count)
        for site in testingSites {
            let address = site.streetAddress + ", " + site.city + ", CA " + site.zip
            makeAnnotation(streetAddress: address, site: site)
        }
        print("Number of testing pins", testingPins.count)
        
        if testingPins.count > 0 {
            print("Setting the focus of the map to pin:", testingSites[0].name)
            self.mapView.setCenter(testingPins[0].coordinate, animated: true)
        }
    }

    // turn street address into point + place point on map + add to testingPin array
    func makeAnnotation(streetAddress: String, site: TestingSite) {
        print("Adding annotation for address: ", streetAddress)
        let geocoder = CLGeocoder()
        // geocoding the address into coordinates
        geocoder.geocodeAddressString(streetAddress) {
            placemarks, error in
            if let placemarks = placemarks {
                if let coordinate = placemarks.first?.location?.coordinate {
                    // add the point to the map
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = coordinate
                    print(annotation.coordinate)
                    annotation.title = site.name
                    annotation.subtitle = site.phone
                    self.testingPins.append(annotation)
                    self.mapView.addAnnotation(annotation)
                    print("Added an annotation to array + mapview")
                }
            }
        }
    }
}

// adding UIPicker functionality
extension MainViewController {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.statesList.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.statesList[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedState = statesList[row]
        //updateLabel.text = "Currently showing testing sites in: selectedState"
        self.updateMap(currentState: self.selectedState)
    }

    @objc func createPickerView() {
        picker = UIPickerView.init()
        picker.delegate = self
        picker.backgroundColor = UIColor.white
        picker.setValue(UIColor.black, forKey: "textColor")
        picker.autoresizingMask = .flexibleWidth
        picker.contentMode = .center
        picker.frame = CGRect.init(x: 0.0, y: UIScreen.main.bounds.size.height - 300, width: UIScreen.main.bounds.size.width, height: 300)
        self.view.addSubview(picker)

        toolBar = UIToolbar.init(frame: CGRect.init(x: 0.0, y: UIScreen.main.bounds.size.height - 300, width: UIScreen.main.bounds.size.width, height: 50))
        toolBar.barStyle = .default
        toolBar.items = [UIBarButtonItem.init(title: "Done", style: .done, target: self, action: #selector(dismissPickerView))]
        self.view.addSubview(toolBar)
    }
    @objc
    func dismissPickerView() {
        toolBar.removeFromSuperview()
        picker.removeFromSuperview()
        updateMap(currentState: selectedState)
    }

    @objc func action() {
       view.endEditing(true)
        print(selectedState)
    }
    
}

// easy extension function for setting fonts.
extension UIFont {
    class func regularFont( size:CGFloat ) -> UIFont{
        return  UIFont(name: "D-DIN", size: size)!
    }
}

// Call the view controller and set up the playground!
let mainView = MainViewController()
mainView.preferredContentSize = CGSize(width: 1000, height: 1000)
PlaygroundPage.current.liveView = mainView

