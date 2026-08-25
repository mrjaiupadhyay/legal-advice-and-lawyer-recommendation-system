import SwiftUI
import CoreData

@main
struct legal_docApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RoleSelectionView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
