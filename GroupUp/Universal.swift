import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage
import UIKit
import MapKit

//  Universal.swift
//  GroupUp
//
//  Created by Samuel Hecht (student LM) on 3/10/20.
//  Copyright © 2020 Samuel Hecht (student LM). All rights reserved.
//
var databaseRef: DatabaseReference = {
    //Database.database().isPersistenceEnabled = true
    return Database.database().reference()
}()
var storageRef = Storage.storage().reference()
var events: [String: Event] = [:]
let map = MKMapView()
let transition = SlideInTransition()
let universe = Universal()
var userImage: UIImage = UIImage(named: "ProfilePic")!
let locationManager = CLLocationManager()
var location = CLLocationCoordinate2D()
var eventLocationCreator = EventLocationCreatorViewController()
let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeZone = .current
    formatter.dateFormat = "EEEE MMMM dd, yyyy    h:mm a"
    formatter.amSymbol = "AM"
    formatter.pmSymbol = "PM"
    return formatter
}()
var usernameToUID = [String: String]()
var usernameToFormattedProfile = [String: NSMutableAttributedString]()
var UIDToUsername = [String: String]()
var viableUsernames = [String]()
var friendDict = [String : Int]()
var friendRequests = [String]()
var friendRequestUsernames = [String]()
var usernames = [String]()

func setUpObservers(){
    guard let uid = Auth.auth().currentUser?.uid else {return}
    databaseRef.child("events").observe(.childAdded) { (eventAdded) in
        let event = getSnapshotAsEvent(snapshot: eventAdded)
        events.updateValue(event, forKey: event.identifier)
        map.addAnnotation(event)
        print("Child Added")
    }
    databaseRef.child("events").observe(.childRemoved) { (eventRemoved) in
        let removedEvent = getSnapshotAsEvent(snapshot: eventRemoved)
        events[removedEvent.identifier] = nil
        print("Child Removed")
    }
    //For if we get to the point where people can edit the events they created
    databaseRef.child("events").observe(.childChanged) { (eventChanged) in
        
        let changedChild = getSnapshotAsEvent(snapshot: eventChanged)
        events[changedChild.identifier] = changedChild
        print("Child Changed")
    }
    
    databaseRef.child("friendRequests/\(uid)").observe(.value) { (snapshot) in
        guard let friendRequestUID = snapshot.value as? [String:String] else {return}
        for key in friendRequestUID.keys{
            friendRequests.append(key)
            guard let friendsRequestUsername = friendRequestUID[key] else {
                print("YIKERS SCOOBS")
                return}
            print("The friend request username is: \(friendsRequestUsername)")
            friendRequestUsernames.append(friendsRequestUsername)
        }
        
    }
    
    
}
func getSnapshotAsEvent(snapshot : DataSnapshot) -> Event{
    guard let eventInformation = snapshot.value as? NSDictionary else {return Event()}
    guard let ownerString = eventInformation["owner"] as? String else {return Event()}
    guard let joinedArray = eventInformation["joined"] as? [String] else {return Event()}
    guard let timeString = eventInformation["time"] as? String else {return Event()}
    guard let name = eventInformation["title"] as? String else {return Event()}
    guard let latitudeString = eventInformation["latitude"] as? String else {return Event()}
    guard let description = eventInformation["description"] as? String else {return Event()}
    guard let activity = eventInformation["activity"] as? String else {return Event()}
    guard let latitudeDouble = Double(latitudeString) else {return Event()}
    guard let longitudeString = eventInformation["longitude"] as? String else {return Event()}
    guard let longitudeDouble = Double(longitudeString) else {return Event()}
    let location = CLLocationCoordinate2D(latitude: latitudeDouble, longitude: longitudeDouble)
    let identifier = snapshot.key
    guard let timeInterval = Double(timeString) else {return Event()}
    
    let time = Date(timeIntervalSinceReferenceDate: timeInterval)
    print(name)
    return Event(title: name, owner: ownerString, coordinate: location, time: time, description : description, joined: joinedArray, activity: activity, identifier: identifier)
    
}
func retrieveUsers(){
    guard let currentUID = Auth.auth().currentUser?.uid else {return}
    databaseRef.child("userProfiles").observeSingleEvent(of: .value, with: {(snapshot) in
        guard let usersDict = snapshot.value as? [String: [String: String]] else {return}
        
        for uid in usersDict.keys{
            guard let userData = usersDict[uid] else {return}
            guard let usernameString = userData["username"] else {return}
            usernameToUID.updateValue(uid, forKey: usernameString)
            UIDToUsername.updateValue(usernameString, forKey: uid)
            //print("UID ME? \(uid == currentUID) FRIEND DICT AT UID IS \(friendDict[uid] ?? -18)")
            
           
            let username = NSAttributedString(string: "  \(usernameString)", attributes: [NSAttributedString.Key.font : UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor : UIColor.systemPink])
            
            
            guard let imageURL = userData["imageURL"] else {
                createImageAndUsernameText(image: UIImage(named: "ProfilePic")!, username: username,usernameText: usernameString)
                if uid != currentUID && friendDict[uid] == nil{
                    print("Hi I'm happening now and only now")
                    usernames.append(usernameString)
                }
                continue
            }
            let storageRef = Storage.storage().reference(forURL: imageURL)
            storageRef.getData(maxSize: 1024*1024) { (data, error) in
                if error == nil && data != nil{
                    createImageAndUsernameText(image: UIImage(data: data!)!, username: username, usernameText: usernameString)
                    
                }
                else{
                    print(error?.localizedDescription)
                }
            }
            if uid != currentUID && friendDict[uid] == nil{
                print("Hi I'm happening now and only now")
                usernames.append(usernameString)
            }
            
        }
    }
    )
    
}
func retrieveFriendsAndUsers(){
    guard let uid = Auth.auth().currentUser?.uid else {return}
    print("HAHAHAHHA")
    databaseRef.child("users/\(uid)/friends").observeSingleEvent(of: .value) { (snapshot) in
        print("BAha")
        guard let friends = snapshot.value as? [String] else {
            retrieveUsers()
            return
            
        }
        for friend in friends{
            print("Walla and the friend is... \(friend)")
            friendDict.updateValue(0, forKey: friend)
        }
        retrieveUsers()
        print("Bruh")
    }
}
func createImageAndUsernameText(image: UIImage, username: NSAttributedString, usernameText: String){
    let imageAttachment = NSTextAttachment()
    imageAttachment.image = image
    let imageOffsetY: CGFloat = -10.0
    imageAttachment.bounds = CGRect(x: 0, y: imageOffsetY, width: 40, height: 40)
    let attachmentString = NSAttributedString(attachment: imageAttachment)
    let completeName = NSMutableAttributedString(string: "")
    completeName.append(attachmentString)
    completeName.append(username)
    usernameToFormattedProfile.updateValue(completeName, forKey: usernameText)
}


func getProfilePicURL(_ completion: @escaping((_ url:String?) -> ())){
    guard let uid = Auth.auth().currentUser?.uid else {return}
    databaseRef.child("users/\(uid)/imageURL").observeSingleEvent(of: .value, with: { (snapshot) in
        guard let url = snapshot.value as? NSString else {return}
        completion(url as String)
    }, withCancel: { (error) in
        print(error.localizedDescription)
    })
    
    
}
func downloadPicture(){
    getProfilePicURL { (url) in
        guard let url = url else {return}
        let ref = Storage.storage().reference(forURL: url)
        ref.getData(maxSize: 1024*1024) { (data, error) in
            if error == nil && data != nil{
                userImage = UIImage(data: data!)!
            }
            else{
                print(error?.localizedDescription)
            }
        }
    }
}
func downloadPicture(withUser uid : String, _ completion: @escaping((UIImage) ->())){
    databaseRef.child("users/\(uid)/imageURL").observeSingleEvent(of: .value) { (snapshot) in
        guard let url = snapshot.value as? String else {return}
        let ref = Storage.storage().reference(forURL: url)
        ref.getData(maxSize: 1024*1024) { (data, error) in
            if error == nil && data != nil{
                completion(UIImage(data: data!)!)
            }
            else{
                print(error?.localizedDescription)
            }
            
        }
    }
    
    
}
func transitiontoNewVC(_ menuType: MenuType, currentViewController: UIViewController){
    //I have a feeling that we'll want to pop to the root before doing any other thing
    //Might have to change the animation stuff tho cuz we won't want the user seeing that
    //This would mean that we uncomment the line below
    //And get rid of the .map case
    //Task for another day
    
    //currentViewController.navigationController?.popToRootViewController(animated: false)
    
    //Just know that if you go back and forth between the profile and friend manager you continue adding them to el stacko... If you go to map once el stacko is gone. 
    switch menuType{
    case .map:
        currentViewController.navigationController?.popToRootViewController(animated: true)
    case .profile:
        if let _ = currentViewController as? ProfileViewController{
            
        }
        else{
            guard let profileViewController = currentViewController.storyboard?.instantiateViewController(withIdentifier: "ProfileViewController") else {return}
            currentViewController.navigationController?.pushViewController(profileViewController, animated: true)
        }
    case .logOut:
        do{
            try Auth.auth().signOut()
        }
        catch{
            print("shoot")
        }
        map.removeOverlays(map.overlays)
        if !map.selectedAnnotations.isEmpty{
            map.deselectAnnotation(map.selectedAnnotations[0], animated: true)
        }
        userImage = UIImage(named: "ProfilePic")!
        usernames = []
        guard let startUpViewController = currentViewController.storyboard?.instantiateViewController(withIdentifier: "StartUpScreenViewController") else {return}
        currentViewController.navigationController?.pushViewController(startUpViewController, animated: true)
        break
    case .friendsManager:
        if let _ = currentViewController as? AddFriendsViewController{
            
        }
        else{
            
            guard let addFriendsViewController = currentViewController.storyboard?.instantiateViewController(withIdentifier: "AddFriendsViewController") else {return}
            currentViewController.navigationController?.pushViewController(addFriendsViewController, animated: true)
            
        }
        break
        
    }
}

func slideOutSidebar(_ currentViewController: UIViewController){
    guard let sidebarMenuViewController = currentViewController.storyboard?.instantiateViewController(withIdentifier: "SidebarMenuViewController") as? SidebarMenuViewController else {return}
    sidebarMenuViewController.didTapMenuType = {menuType in
        transitiontoNewVC(menuType, currentViewController: currentViewController)
    }
    sidebarMenuViewController.modalPresentationStyle = .overCurrentContext
    sidebarMenuViewController.transitioningDelegate = universe
    currentViewController.present(sidebarMenuViewController, animated: true)
    //Yo idk if you fellas want this but at least while the
    //Event manager is empty it looks bad with both up cuz the
    //Map gets blocked so...
    if let mapViewController = currentViewController as? MapViewController{
        mapViewController.eventManagerSlideUpView.popUpViewToBottom()
    }
    
}

class Universal: NSObject, UIViewControllerTransitioningDelegate{
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.isPresenting = true
        return transition
    }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.isPresenting = false
        return transition
    }
}

