//
//  APIClient.swift
//  hackyeah
//
//  Created by Dominik Kapusta on 28/10/2017.
//  Copyright © 2017 Base. All rights reserved.
//

import UIKit

extension BeaconData {
    var name: String? {
        switch self {
        case .BC1:
            return "bc1"
        case .BC2:
            return "bc2"
        case .BC3:
            return "bc3"
        default:
            return nil
        }
    }
}

class APIClient: NSObject, URLSessionDelegate {
    
    static let shared = APIClient()
    
    var isUserLoggedIn: Bool {
        return currentTeamID != nil && currentUserID != nil
    }
    
    private(set) var currentTeamID: Int64? = nil
    private(set) var currentUserID: Int64? = nil
    
    override init() {
        if let teamID = UserDefaults.standard.value(forKey: "teamID") as? NSNumber {
            currentTeamID = teamID.int64Value
            currentUserID = 1
        }
    }
    
    func logIn(teamID: Int64, userID: Int64, completionHandler: ((Bool) -> Void)) {
        currentTeamID = teamID
        currentUserID = userID
        UserDefaults.standard.set(NSNumber(value: teamID), forKey: "teamID")
        UserDefaults.standard.synchronize()
        completionHandler(true)
    }

    func logOut(completionHandler: ((Bool) -> Void)) {
        currentTeamID = nil
        currentUserID = nil
        UserDefaults.standard.removeObject(forKey: "teamID")
        UserDefaults.standard.synchronize()
        completionHandler(true)
    }

    func update(latitude: Double, longitude: Double, beacons: [BeaconData]) {
        guard let userID = currentUserID, let teamID = currentTeamID else { return }
        let urlString = "https://michalgalka.pl:5000/api/ctf/pos/\(teamID)/\(userID)"
        var request: URLRequest = URLRequest(url: URL(string: urlString)!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let dict: [String:Any] = ["lat": latitude, "lon": longitude, "beacons": beacons.flatMap({$0.name})]
        request.httpMethod = "POST"
        
        do {
        
            request.httpBody = try JSONSerialization.data(withJSONObject: dict, options: [])
            let task = urlSession.dataTask(with: request) { (data, response, error) in
                if let responseData = data {
                    do {
                        let responseJSON = try JSONSerialization.jsonObject(with: responseData, options: [])
                        NSLog("response: \(responseJSON)")
                    } catch (let error) {
                        NSLog("JSON serialization error: \(error)")
                    }
                }
            }
            NSLog("\(urlString): \(dict)")
            task.resume()

        } catch (let error) {
            NSLog("JSON serialization error: \(error)")
        }
        
    }
    
    // MARK: - URLSession
    
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration,
                          delegate: self,
                          delegateQueue: workerQueue)
    }()
    
    private let workerQueue = OperationQueue()
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if challenge.protectionSpace.host == "michalgalka.pl" {
                
                if let certFile = Bundle.main.path(forResource: "cert", ofType: "der"),
                    let data = try? Data(contentsOf: URL(fileURLWithPath: certFile)),
                    let cert = SecCertificateCreateWithData(nil, data as CFData),
                    let trust = challenge.protectionSpace.serverTrust
                {
                    SecTrustSetAnchorCertificates(trust, [cert] as CFArray)
                    completionHandler(.useCredential, URLCredential(trust: trust))
                } else {
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }

}
