//
//  LawyerRegistrationView.swift
//  legal_doc
//
//  Registration screen for lawyers to create accounts
//

import SwiftUI
import CoreData
import Combine

class LawyerAuthManager: ObservableObject {
    @Published var currentLawyerID: UUID?
    
    private let lawyerIDKey = "currentLawyerID"
    
    init() {
        if let uuidString = UserDefaults.standard.string(forKey: lawyerIDKey),
           let uuid = UUID(uuidString: uuidString) {
            currentLawyerID = uuid
        }
    }
    
    func setCurrentLawyer(_ lawyerID: UUID) {
        currentLawyerID = lawyerID
        UserDefaults.standard.set(lawyerID.uuidString, forKey: lawyerIDKey)
    }
    
    func logout() {
        currentLawyerID = nil
        UserDefaults.standard.removeObject(forKey: lawyerIDKey)
    }
}

struct LawyerRegistrationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: LawyerAuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var barNumber = ""
    @State private var experience = ""
    @State private var hourlyRate = ""
    @State private var bio = ""
    @State private var selectedSpecializations: Set<String> = []
    @State private var errorMessage = ""
    @State private var isRegistering = false
    
    let categories = [
        "Criminal Law",
        "Civil Law",
        "Family Law",
        "Cyber Law"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Full Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section(header: Text("Professional Details")) {
                    TextField("Bar Number", text: $barNumber)
                    TextField("Years of Experience", text: $experience)
                        .keyboardType(.numberPad)
                    TextField("Hourly Rate ($)", text: $hourlyRate)
                        .keyboardType(.decimalPad)
                    
                    TextEditor(text: $bio)
                        .frame(height: 100)
                        .overlay(
                            Group {
                                if bio.isEmpty {
                                    Text("Brief bio about your legal expertise...")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section(header: Text("Specializations")) {
                    ForEach(categories, id: \.self) { category in
                        Toggle(category, isOn: Binding(
                            get: { selectedSpecializations.contains(category) },
                            set: { isOn in
                                if isOn {
                                    selectedSpecializations.insert(category)
                                } else {
                                    selectedSpecializations.remove(category)
                                }
                            }
                        ))
                    }
                }
                
                Section {
                    Button(action: registerLawyer) {
                        HStack {
                            if isRegistering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!isFormValid || isRegistering)
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Lawyer Registration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        !phone.isEmpty &&
        !barNumber.isEmpty &&
        !selectedSpecializations.isEmpty
    }
    
    private func registerLawyer() {
        guard isFormValid else { return }
        
        isRegistering = true
        errorMessage = ""
        
        // Check if email already exists
        let emailFetch: NSFetchRequest<Lawyer> = Lawyer.fetchRequest()
        emailFetch.predicate = NSPredicate(format: "email == %@", email)
        
        if let existingLawyer = try? viewContext.fetch(emailFetch).first {
            errorMessage = "A lawyer with this email already exists"
            isRegistering = false
            return
        }
        
        // Create lawyer
        let lawyer = Lawyer(context: viewContext)
        lawyer.lawyerID = UUID()
        lawyer.name = name
        lawyer.email = email
        lawyer.phone = phone
        lawyer.barNumber = barNumber
        lawyer.experience = Int16(experience) ?? 0
        lawyer.hourlyRate = Double(hourlyRate) ?? 0.0
        lawyer.bio = bio.isEmpty ? "Experienced legal professional" : bio
        lawyer.rating = 0.0
        lawyer.dateCreated = Date()
        
        // Add specializations
        for categoryName in selectedSpecializations {
            let categoryFetch: NSFetchRequest<LegalCategory> = LegalCategory.fetchRequest()
            categoryFetch.predicate = NSPredicate(format: "name == %@", categoryName)
            
            var category: LegalCategory
            if let existingCategory = try? viewContext.fetch(categoryFetch).first {
                category = existingCategory
            } else {
                category = LegalCategory(context: viewContext)
                category.categoryID = UUID()
                category.name = categoryName
                category.categoryDescription = "Legal category: \(categoryName)"
                category.dateCreated = Date()
            }
            
            lawyer.addToSpecializations(category)
        }
        
        // Save
        do {
            try viewContext.save()
            authManager.setCurrentLawyer(lawyer.lawyerID!)
            isRegistering = false
            dismiss()
        } catch {
            errorMessage = "Error creating account: \(error.localizedDescription)"
            isRegistering = false
        }
    }
}
