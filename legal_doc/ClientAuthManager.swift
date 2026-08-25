//
//  ClientAuthManager.swift
//  legal_doc
//
//  Authentication manager for clients
//

import Foundation
import Combine

class ClientAuthManager: ObservableObject {
    @Published var currentUserID: UUID?
    
    private let userIDKey = "currentClientUserID"
    
    init() {
        if let uuidString = UserDefaults.standard.string(forKey: userIDKey),
           let uuid = UUID(uuidString: uuidString) {
            currentUserID = uuid
        }
    }
    
    func setCurrentUser(_ userID: UUID) {
        currentUserID = userID
        UserDefaults.standard.set(userID.uuidString, forKey: userIDKey)
    }
    
    func logout() {
        currentUserID = nil
        UserDefaults.standard.removeObject(forKey: userIDKey)
    }
}
