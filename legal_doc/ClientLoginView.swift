//
//  ClientLoginView.swift
//  legal_doc
//
//  Login screen for clients
//

import SwiftUI
import CoreData

struct ClientLoginView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: ClientAuthManager
    @State private var email = ""
    @State private var errorMessage = ""
    @State private var showRegistration = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Logo
                VStack(spacing: 10) {
                    LogoView(size: 100)
                    Text("Client Portal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Sign in to access your account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 50)
                
                // Login Form
                VStack(spacing: 20) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal)
                    
                    Button(action: login) {
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(email.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(email.isEmpty)
                    .padding(.horizontal)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    Button(action: { showRegistration = true }) {
                        Text("Create New Account")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Client Login")
            .sheet(isPresented: $showRegistration) {
                ClientRegistrationView()
                    .environmentObject(authManager)
            }
        }
    }
    
    private func login() {
        guard !email.isEmpty else { return }
        
        let emailFetch: NSFetchRequest<User> = User.fetchRequest()
        emailFetch.predicate = NSPredicate(format: "email == %@", email)
        
        if let user = try? viewContext.fetch(emailFetch).first {
            if let userID = user.userID {
                authManager.setCurrentUser(userID)
                errorMessage = ""
            } else {
                errorMessage = "User account is missing ID. Please create a new account."
            }
        } else {
            errorMessage = "No account found with this email. Please create an account."
        }
    }
}

struct ClientRegistrationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: ClientAuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var errorMessage = ""
    @State private var isRegistering = false
    
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
                    TextField("Address (Optional)", text: $address)
                }
                
                Section {
                    Button(action: registerClient) {
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
            .navigationTitle("Client Registration")
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
        !phone.isEmpty
    }
    
    private func registerClient() {
        guard isFormValid else { return }
        
        isRegistering = true
        errorMessage = ""
        
        // Check if email already exists
        let emailFetch: NSFetchRequest<User> = User.fetchRequest()
        emailFetch.predicate = NSPredicate(format: "email == %@", email)
        
        if let existingUser = try? viewContext.fetch(emailFetch).first {
            errorMessage = "An account with this email already exists"
            isRegistering = false
            return
        }
        
        // Create user
        let user = User(context: viewContext)
        user.userID = UUID()
        user.name = name
        user.email = email
        user.phone = phone
        user.address = address.isEmpty ? nil : address
        user.dateCreated = Date()
        
        // Save
        do {
            try viewContext.save()
            authManager.setCurrentUser(user.userID!)
            isRegistering = false
            dismiss()
        } catch {
            errorMessage = "Error creating account: \(error.localizedDescription)"
            isRegistering = false
        }
    }
}
