//
//  Persistence.swift
//  legal_doc
//
//  Created by jai upadhyay on 15/10/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for preview
        let sampleUser = User(context: viewContext)
        sampleUser.userID = UUID()
        sampleUser.name = "John Doe"
        sampleUser.email = "john@example.com"
        sampleUser.phone = "+1234567890"
        sampleUser.dateCreated = Date()
        
        let sampleCategory = LegalCategory(context: viewContext)
        sampleCategory.categoryID = UUID()
        sampleCategory.name = "Criminal Law"
        sampleCategory.categoryDescription = "Legal matters related to criminal offenses"
        sampleCategory.dateCreated = Date()
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "legal_doc")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Handle Core Data errors
                let errorCode = error.code
                
                // Check if it's a migration/schema mismatch error
                if errorCode == NSPersistentStoreIncompatibleVersionHashError || 
                   errorCode == NSMigrationMissingSourceModelError {
                    print("⚠️ Core Data Schema Mismatch Detected")
                    print("📝 Error: \(error.localizedDescription)")
                    print("💡 To fix: Delete the app from simulator/device and reinstall")
                    print("   This happens when the Core Data model changes.")
                    
                    // In development, we can continue but logging won't work until fixed
                    return
                }
                
                // For other critical errors, still log but don't always crash
                print("❌ Core Data Error: \(error.localizedDescription)")
                print("   User Info: \(error.userInfo)")
                
                // Only crash in debug mode for non-migration errors
                #if DEBUG
                if errorCode != NSPersistentStoreIncompatibleVersionHashError &&
                   errorCode != NSMigrationMissingSourceModelError {
                    fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
                }
                #endif
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
