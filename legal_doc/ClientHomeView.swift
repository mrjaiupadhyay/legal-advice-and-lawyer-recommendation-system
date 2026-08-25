//
//  ClientHomeView.swift
//  legal_doc
//
//  Home screen for clients to submit queries and view their history
//

import SwiftUI
import CoreData

struct ClientHomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authManager = ClientAuthManager()
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if authManager.currentUserID != nil {
                // Client is logged in
                TabView(selection: $selectedTab) {
                    // Submit Query Tab
                    QuerySubmissionView()
                        .environmentObject(authManager)
                        .tabItem {
                            Label("Submit Query", systemImage: "plus.circle.fill")
                        }
                        .tag(0)
                    
                    // My Queries Tab
                    QueryListView()
                        .tabItem {
                            Label("My Queries", systemImage: "list.bullet")
                        }
                        .tag(1)
                    
                    // Profile Tab
                    ClientProfileView()
                        .environmentObject(authManager)
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                        .tag(2)
                }
                .navigationBarTitleDisplayMode(.inline)
            } else {
                // Show login screen
                ClientLoginView()
                    .environmentObject(authManager)
            }
        }
    }
}

struct QuerySubmissionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: ClientAuthManager
    
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
    @State private var suggestedLawyers: [Lawyer] = []
    @State private var isLoadingLawyers = false
    @State private var showSuggestedLawyers = false
    
    private let aiService = AIService()
    private let matchingService = LawyerMatchingService()
    
    private var currentUser: User? {
        guard let userID = authManager.currentUserID else { return nil }
        let fetch: NSFetchRequest<User> = User.fetchRequest()
        fetch.predicate = NSPredicate(format: "userID == %@", userID as CVarArg)
        return try? viewContext.fetch(fetch).first
    }
    
    let categories = [
        "Criminal Law",
        "Civil Law",
        "Family Law",
        "Cyber Law"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                if let user = currentUser {
                    Section(header: Text("Logged in as")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(user.name ?? "User")
                                    .font(.headline)
                                Text(user.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(user.phone ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
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
                
                if isLoadingLawyers {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Finding matching lawyers...")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if showSuggestedLawyers && !suggestedLawyers.isEmpty {
                    Section(header: Text("Suggested Lawyers")) {
                        Text("Based on your query, here are lawyers who can help:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        ForEach(suggestedLawyers.prefix(5), id: \.lawyerID) { lawyer in
                            LawyerSuggestionCard(lawyer: lawyer)
                        }
                    }
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Submit Query")
        }
    }
    
    private func submitQuery() {
        // Use logged-in user
        guard let user = currentUser else {
            errorMessage = "Please log in to submit a query"
            return
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
        query.title = "Query from \(user.name ?? "User")"
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
            
            // Generate AI response and find matching lawyers
            Task {
                await generateAIResponse(for: query, category: selectedCategory)
                await findMatchingLawyers(for: query)
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
    
    private func findMatchingLawyers(for query: LegalQuery) async {
        isLoadingLawyers = true
        suggestedLawyers = []
        showSuggestedLawyers = false
        
        let lawyers = await matchingService.findMatchingLawyers(for: query, in: viewContext)
        
        await MainActor.run {
            suggestedLawyers = lawyers
            isLoadingLawyers = false
            showSuggestedLawyers = !lawyers.isEmpty
        }
    }
}

struct LawyerSuggestionCard: View {
    @ObservedObject var lawyer: Lawyer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(lawyer.name ?? "Lawyer")
                        .font(.headline)
                    if let specializations = lawyer.specializations as? Set<LegalCategory> {
                        Text(specializations.map { $0.name ?? "" }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", lawyer.rating))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    Text(String(format: "$%.0f/hr", lawyer.hourlyRate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let bio = lawyer.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("\(lawyer.experience) years exp.", systemImage: "briefcase.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let phone = lawyer.phone {
                    Label(phone, systemImage: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ClientProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: ClientAuthManager
    
    private var currentUser: User? {
        guard let userID = authManager.currentUserID else { return nil }
        let fetch: NSFetchRequest<User> = User.fetchRequest()
        fetch.predicate = NSPredicate(format: "userID == %@", userID as CVarArg)
        return try? viewContext.fetch(fetch).first
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LegalQuery.dateCreated, ascending: false)],
        animation: .default)
    private var queries: FetchedResults<LegalQuery>
    
    private var myQueries: [LegalQuery] {
        guard let userID = authManager.currentUserID else { return [] }
        return Array(queries.filter { $0.user?.userID == userID })
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let user = currentUser {
                    Section(header: Text("Profile Information")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(user.name ?? "User")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(user.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        InfoRow(label: "Name", value: user.name ?? "N/A")
                        InfoRow(label: "Email", value: user.email ?? "N/A")
                        InfoRow(label: "Phone", value: user.phone ?? "N/A")
                        
                        if let address = user.address, !address.isEmpty {
                            InfoRow(label: "Address", value: address)
                        }
                        
                        if let dateCreated = user.dateCreated {
                            InfoRow(label: "Member Since", value: formatDate(dateCreated))
                        }
                    }
                    
                    Section(header: Text("Statistics")) {
                        HStack {
                            Text("Total Queries")
                            Spacer()
                            Text("\(myQueries.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        authManager.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("My Profile")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
