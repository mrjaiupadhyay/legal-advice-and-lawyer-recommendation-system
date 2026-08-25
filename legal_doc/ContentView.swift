import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var legalQuery = ""
    @State private var selectedCategory = "Criminal Law"
    @State private var isSubmitted = false
    @State private var errorMessage = ""
    @State private var aiResponse: String = ""
    @State private var isLoadingAI = false
    @State private var showAIResponse = false
    
    private let aiService = AIService()

    let categories = [
        "Criminal Law",
        "Civil Law",
        "Family Law",
        "Cyber Law"
    ]

    var body: some View {
        NavigationView {
            Form {

                Section(header: Text("User Information")) {
                    TextField("Name", text: $name)
                    TextField("Phone Number", text: $phone)
                    TextField("Email ID", text: $email)
                }

                Section(header: Text("Legal Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                        }
                    }
                }

                Section(header: Text("Legal Query")) {
                    TextEditor(text: $legalQuery)
                        .frame(height: 100)
                }

                Button("Submit Query") {
                    submitQuery()
                }

                if isSubmitted {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Query Submitted Successfully")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                if isLoadingAI {
                    Section {
                        HStack {
                            ProgressView()
                            Text("AI is analyzing your query...")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if showAIResponse && !aiResponse.isEmpty {
                    Section(header: Text("AI Legal Assistant Response")) {
                        ScrollView {
                            Text(aiResponse)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 300)
                    }
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Pocket Lawyer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: QueryListView()) {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
    }
    
    private func submitQuery() {
        // Find or create user
        let userFetch: NSFetchRequest<User> = User.fetchRequest()
        userFetch.predicate = NSPredicate(format: "email == %@", email)
        
        var user: User
        if let existingUser = try? viewContext.fetch(userFetch).first {
            user = existingUser
            if user.userID == nil {
                user.userID = UUID()
            }
            user.name = name
            user.phone = phone
        } else {
            user = User(context: viewContext)
            user.userID = UUID()
            user.name = name
            user.email = email
            user.phone = phone
            user.dateCreated = Date()
        }
        
        // Find or create category
        let categoryFetch: NSFetchRequest<LegalCategory> = LegalCategory.fetchRequest()
        categoryFetch.predicate = NSPredicate(format: "name == %@", selectedCategory)
        
        var category: LegalCategory
        if let existingCategory = try? viewContext.fetch(categoryFetch).first {
            category = existingCategory
            if category.categoryID == nil {
                category.categoryID = UUID()
            }
        } else {
            category = LegalCategory(context: viewContext)
            category.categoryID = UUID()
            category.name = selectedCategory
            category.categoryDescription = "Legal category: \(selectedCategory)"
            category.dateCreated = Date()
        }
        
        // Create legal query
        let query = LegalQuery(context: viewContext)
        query.queryID = UUID()
        query.title = "Query from \(name)"
        query.queryDescription = legalQuery
        query.dateCreated = Date()
        query.dateUpdated = Date()
        query.user = user
        query.category = category
        
        // Create case status
        let caseStatus = CaseStatus(context: viewContext)
        caseStatus.statusID = UUID()
        caseStatus.status = "Submitted"
        caseStatus.notes = "Query submitted and awaiting lawyer response"
        caseStatus.dateUpdated = Date()
        caseStatus.query = query
        
        // Save context
        do {
            try viewContext.save()
            isSubmitted = true
            errorMessage = ""
            
            // Generate AI response
            Task {
                await generateAIResponse(for: query, category: selectedCategory)
            }
        } catch {
            errorMessage = "Error saving query: \(error.localizedDescription)"
            isSubmitted = false
        }
    }
    
    private func generateAIResponse(for query: LegalQuery, category: String) async {
        isLoadingAI = true
        aiResponse = ""
        showAIResponse = false
        
        do {
            let response = try await aiService.generateLegalResponse(
                query: query.queryDescription ?? legalQuery,
                category: category
            )
            
            await MainActor.run {
                aiResponse = response
                isLoadingAI = false
                showAIResponse = true
                
                // Save AI response to Core Data
                saveAIResponse(response: response, to: query)
            }
        } catch {
            await MainActor.run {
                isLoadingAI = false
                errorMessage = "AI service error: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveAIResponse(response: String, to query: LegalQuery) {
        // Find or create AI Lawyer entity
        let lawyerFetch: NSFetchRequest<Lawyer> = Lawyer.fetchRequest()
        lawyerFetch.predicate = NSPredicate(format: "email == %@", "ai@pocketlawyer.com")
        
        var aiLawyer: Lawyer
        if let existingLawyer = try? viewContext.fetch(lawyerFetch).first {
            aiLawyer = existingLawyer
        } else {
            aiLawyer = Lawyer(context: viewContext)
            aiLawyer.lawyerID = UUID()
            aiLawyer.name = "AI Legal Assistant"
            aiLawyer.email = "ai@pocketlawyer.com"
            aiLawyer.bio = "AI-powered legal assistant providing general legal information"
            aiLawyer.dateCreated = Date()
        }
        
        // Create lawyer response
        let lawyerResponse = LawyerResponse(context: viewContext)
        lawyerResponse.responseID = UUID()
        lawyerResponse.content = response
        lawyerResponse.dateCreated = Date()
        lawyerResponse.isAccepted = false
        lawyerResponse.lawyer = aiLawyer
        lawyerResponse.query = query
        
        // Update case status
        if let caseStatus = query.caseStatus {
            caseStatus.status = "AI Response Received"
            caseStatus.notes = "AI assistant has provided an initial response"
            caseStatus.dateUpdated = Date()
        }
        
        // Save context
        do {
            try viewContext.save()
        } catch {
            errorMessage = "Error saving AI response: \(error.localizedDescription)"
        }
    }
}
