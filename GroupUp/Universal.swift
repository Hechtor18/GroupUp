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
    Database.database().isPersistenceEnabled = true
    return Database.database().reference()
}()
var storageRef = Storage.storage().reference()
var events: [String: Event] = [:]
let map = MKMapView()
var strokeColor: UIColor = UIColor.clear
let transition = SlideInTransition()
let universe = Universal()
var userImage: UIImage = UIImage(named: "ProfilePic")!
let locManager = CLLocationManager()
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
var myFriends = [String]()
var friendRequests = [String]()
var friendRequestUsernames = [String]()
var usernames = [String]()
var myCreatedEvents = [String]()
var joinedEvents = [String]()


func setUpObservers(){
    
    var pendingNotificationIDs = [String]()
    UNUserNotificationCenter.current().getPendingNotificationRequests { (requests) in
        for request in requests {
            pendingNotificationIDs.append(request.identifier)
        }
    }
    
    guard let uid = Auth.auth().currentUser?.uid else {return}
    
    
    
    databaseRef.child("events").observe(.childAdded) { (eventAdded) in
        let event = getSnapshotAsEvent(snapshot: eventAdded)
        print("Child added")
        print("The my friends contains \(myFriends.count) people")
        if (event.permission == "Friends" && (myFriends.contains(event.owner) || uid == event.owner)
            || event.permission == "Anyone"){
            
            
            if event.time < Date(timeIntervalSinceNow: 0) {
                databaseRef.child("events/\(event.identifier)").removeValue()
                let description = event.subtitle ?? ""
                let eventDictionary = [
                    "owner" : event.owner,
                    "joined" : event.joined,
                    "time" : event.time.timeIntervalSinceReferenceDate,
                    "title" : event.title!,
                    "latitude" : "\(event.coordinate.latitude)",
                    "longitude" : "\(event.coordinate.longitude)" ,
                    "description" : description,
                    "activity" : event.activity,
                    "permission" : event.permission
                    ] as [String : Any]
                databaseRef.child("prevEvents").updateChildValues([event.identifier : eventDictionary])
            }
            else{
                events.updateValue(event, forKey: event.identifier)
                map.addAnnotation(event)
                //print("Child Added")
            }
            print("This continues to happen even though we persisting")
        }
        else{
            print("The owner is: \(event.owner) and I am \(uid)")
        }
    }
    
    databaseRef.child("events").observe(.childRemoved) { (eventRemoved) in
        let removedEvent = getSnapshotAsEvent(snapshot: eventRemoved)
        events[removedEvent.identifier] = nil
        map.removeAnnotation(removedEvent)
        print("Child Removed")
    }
    //For if we get to the point where people can edit the events they created
    databaseRef.child("events").observe(.childChanged) { (eventChanged) in
        
        let changedChild = getSnapshotAsEvent(snapshot: eventChanged)
        events[changedChild.identifier] = changedChild
        print("Child Changed")
    }
    
    databaseRef.child("friendRequests/\(uid)").observe(.value) { (snapshot) in
        print("Getting dem friend reqs")
        guard let friendRequestUsers = snapshot.value as? [String:String] else {return}
        for username in friendRequestUsers.keys{
            friendRequestUsernames.append(username)
            guard let friendsRequestUID = friendRequestUsers[username] else {
                print("YIKERS SCOOBS")
                return}
            print("The friend request uid is: \(friendsRequestUID)")
            friendRequests.append(friendsRequestUID)
            guard let index = usernames.firstIndex(of: username) else {return}
            usernames.remove(at: index)
            
        }
        
    }
    
    
    databaseRef.child("users/\(uid)/friends").observe(.childAdded) { (snapshot) in
        guard let friend = snapshot.value as? String else {return}
        if !myFriends.contains(friend){
            myFriends.append(friend)
        }
    }
    
    
    databaseRef.child("users/\(uid)/joined").observeSingleEvent(of: .value) { (snapshot) in
        print("Welcome to the thunder dome")
        guard let joined = snapshot.value as? [String] else {return}
        joinedEvents = joined
        
        
        for i in 0..<joined.count{
            
            let content = UNMutableNotificationContent()
            content.title = "An event you joined occurs in 10 minutes"
            content.body = "Make sure to go to your event"
            databaseRef.child("events/\(joined[i])/time").observeSingleEvent(of: .value) { (snapshot) in
                guard let timeIntervalString = snapshot.value as? String else {return}
                guard let timeInterval = Double(timeIntervalString) else {return}
                let notificationCenter = UNUserNotificationCenter.current()
                if !pendingNotificationIDs.contains("\(timeInterval-600)") &&
                Date(timeIntervalSinceReferenceDate: timeInterval-600).timeIntervalSinceNow > 0{
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Date(timeIntervalSinceReferenceDate: timeInterval-600).timeIntervalSinceNow, repeats: false)
                    
                    let request = UNNotificationRequest(identifier: "\(timeInterval-600)", content: content, trigger: trigger)
                    
                    notificationCenter.add(request) { (error) in
                        if error != nil{
                            print(error?.localizedDescription)
                            print(error.debugDescription)
                            print("Something went wronggggg duh duh duh duh duh but I made it!")
                        }
                        else{
                            print("Congerts bro you set a notification for the event you joined happening: \(dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timeInterval-600)))")
                        }
                    }
                }
                
                
                if !pendingNotificationIDs.contains("\(timeInterval-3600)") &&
                    Date(timeIntervalSinceReferenceDate: timeInterval-3600).timeIntervalSinceNow > 0{
                    let hourContent = UNMutableNotificationContent()
                    hourContent.title = "An event you joined occurs in 1 hour"
                    hourContent.body = "Make sure to go to your event"
                    let hourTrigger = UNTimeIntervalNotificationTrigger(timeInterval: Date(timeIntervalSinceReferenceDate: timeInterval-3600).timeIntervalSinceNow, repeats: false)
                    let hourRequest = UNNotificationRequest(identifier: "\(timeInterval-3600)", content: hourContent, trigger: hourTrigger)
                    notificationCenter.add(hourRequest, withCompletionHandler: nil)
                }
            }
        }
    }
    databaseRef.child("users/\(uid)/created").observeSingleEvent(of: .value) { (snapshot) in
        print("Welcome to the thunder dome but I made it!")
        guard let created = snapshot.value as? [String] else {return}
        print("")
        myCreatedEvents = created
        
        for i in 0..<created.count{
            
            let content = UNMutableNotificationContent()
            content.title = "An event you created occurs in 10 minutes!"
            content.body = "Make sure to go to your event!"
            let notificationCenter = UNUserNotificationCenter.current()
            
            databaseRef.child("events/\(created[i])/time").observeSingleEvent(of: .value) { (snapshot) in
                guard let timeIntervalString = snapshot.value as? String else {return}
                guard let timeInterval = Double(timeIntervalString) else {return}
                if !pendingNotificationIDs.contains("\(timeInterval-600)") && Date(timeIntervalSinceReferenceDate: timeInterval-600).timeIntervalSinceNow > 0{
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Date(timeIntervalSinceReferenceDate: timeInterval-600).timeIntervalSinceNow, repeats: false)
                    
                    let request = UNNotificationRequest(identifier: "\(timeInterval-600)", content: content, trigger: trigger)
                    notificationCenter.add(request) { (error) in
                        if error != nil{
                            print(error?.localizedDescription)
                            print(error.debugDescription)
                            print("Something went wronggggg duh duh duh duh duh but I made it!")
                        }
                        else{
                            print("Congerts bro you set a notification for the event you created happening: \(dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: timeInterval-600)))")
                        }
                    }
                }
                
                
                if !pendingNotificationIDs.contains("\(timeInterval-3600)") &&
                Date(timeIntervalSinceReferenceDate: timeInterval-3600).timeIntervalSinceNow > 0{
                    let hourContent = UNMutableNotificationContent()
                    hourContent.title = "An event you created occurs in 1 hour"
                    hourContent.body = "Make sure to go to your event"
                    let hourTrigger = UNTimeIntervalNotificationTrigger(timeInterval: Date(timeIntervalSinceReferenceDate: timeInterval-3600).timeIntervalSinceNow, repeats: false)
                    let hourRequest = UNNotificationRequest(identifier: "\(timeInterval-3600)", content: hourContent, trigger: hourTrigger)
                    notificationCenter.add(hourRequest, withCompletionHandler: nil)
                }
                
            }
            
            
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
    guard let permission = eventInformation["permissions"] as? String else {return Event()}
    guard let latitudeDouble = Double(latitudeString) else {return Event()}
    guard let longitudeString = eventInformation["longitude"] as? String else {return Event()}
    guard let longitudeDouble = Double(longitudeString) else {return Event()}
    
    let location = CLLocationCoordinate2D(latitude: latitudeDouble, longitude: longitudeDouble)
    let identifier = snapshot.key
    guard let timeInterval = Double(timeString) else {return Event()}
    
    let time = Date(timeIntervalSinceReferenceDate: timeInterval)
    print(name)
    return Event(title: name, owner: ownerString, coordinate: location, time: time, description : description, joined: joinedArray, activity: activity, identifier: identifier, permission: permission)
    
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
            
            
            
            
            let username = NSAttributedString(string: "  \(usernameString)", attributes: [NSAttributedString.Key.font : UIFont(name: "HelveticaNeue-Bold", size: 24)!, NSAttributedString.Key.foregroundColor : UIColor(red: 208/255.0, green: 222/255.0, blue: 39/255.0, alpha: 1.0)])
            
            
            guard let imageURL = userData["imageURL"] else {
                createImageAndUsernameText(image: UIImage(named: "ProfilePic")!, username: username,usernameText: usernameString)
                if uid != currentUID && !myFriends.contains(uid) && !friendRequests.contains(uid){
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
            if uid != currentUID && !myFriends.contains(uid) && !friendRequests.contains(uid){
                print("Hi I'm happening now and only now")
                usernames.append(usernameString)
            }
            
        }
    }
    )
    
}
func resetEverything(){
    
    databaseRef.removeAllObservers()
    events = [:]
    
    userImage = UIImage(named: "ProfilePic")!
    
    location = CLLocationCoordinate2D()
    if !map.annotations.isEmpty{
        map.removeAnnotations(map.annotations)
    }
    
    viableUsernames = [String]()
    myFriends = [String]()
    friendRequests = [String]()
    friendRequestUsernames = [String]()
    usernames = [String]()
    myCreatedEvents = [String]()
    joinedEvents = [String]()
    retrieveFriendsAndUsers()
    
    
}
func retrieveFriendsAndUsers(){
    guard let uid = Auth.auth().currentUser?.uid else {return}
    print("HAHAHAHHA")
    databaseRef.child("users/\(uid)/friends").observeSingleEvent(of: .value) { (snapshot) in
        print("BAha")
        guard let friends = snapshot.value as? [String] else {
            retrieveUsers()
            setUpObservers()
            return
            
        }
        for friend in friends{
            print("Walla and the friend is... \(friend)")
            myFriends.append(friend)
        }
        retrieveUsers()
        setUpObservers()
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
    print("Why on earth is the side bar sliding out but not...?")
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

