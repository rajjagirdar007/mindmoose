//
//  File.swift
//  mindmoose
//
//  Created by Raj Jagirdar on 2/23/25.
//

import Foundation
// MARK: - VoiceTasksApp.swift
import SwiftUI
import Firebase
import FirebaseAppCheck

// MARK: - VoiceTasksApp.swift
import SwiftUI
import Firebase
import FirebaseAppCheck

@main
struct VoiceTasksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.indigo)
        }
    }
}


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("AppCheck Debug Provider enabled.")
        #endif

        FirebaseApp.configure()
        print("Firebase configured successfully.")
        return true
    }
}

// MARK: - PersistenceController.swift
import CoreData
import UIKit

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TaskEntity")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data: \(error.localizedDescription)")
            }
            print("Core Data store loaded: \(description)")
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveContextInBackground()
        }
    }

    private func saveContextInBackground() {
        container.performBackgroundTask { backgroundContext in
            if backgroundContext.hasChanges {
                do {
                    try backgroundContext.save()
                    print("Background context saved successfully.")
                } catch {
                    print("Error saving context in background: \(error)")
                }
            }
        }
    }

    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("Main context saved successfully.")
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
}

// MARK: - Models/Task.swift
import FirebaseFirestore

struct Task2: Identifiable, Codable {
    @DocumentID var id: String?
    var taskDescription: String
    var category: String
    var isCompleted: Bool
    var timestamp: Timestamp
    var priority: Int16
    var notes: String?
    var dueDate: Timestamp?

    var documentID: String {
        return id ?? UUID().uuidString
    }

    enum CodingKeys: String, CodingKey {
        case id, taskDescription, category, isCompleted, timestamp, priority, notes, dueDate
    }

    init(id: String? = nil, taskDescription: String, category: String, isCompleted: Bool, timestamp: Timestamp, priority: Int16, notes: String? = nil, dueDate: Timestamp? = nil) {
        self.id = id
        self.taskDescription = taskDescription
        self.category = category
        self.isCompleted = isCompleted
        self.timestamp = timestamp
        self.priority = priority
        self.notes = notes
        self.dueDate = dueDate
    }
}

// MARK: - Services/FirebaseService.swift
import FirebaseFirestore
import Combine

// MARK: - Services/FirebaseService.swift
import FirebaseFirestore
import FirebaseAuth
import Combine

class FirebaseService: ObservableObject {
    @Published var tasks: [Task2] = []
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if user != nil {
                self?.loadTasks()
            } else {
                self?.tasks = []
                self?.listener?.remove()
            }
        }
    }
    
    deinit {
        listener?.remove()
    }
    
    func loadTasks() {
        guard let userId = userId else {
            print("No authenticated user found.")
            return
        }
        
        listener?.remove() // Remove existing listener before creating a new one
        
        listener = db.collection("users")
            .document(userId)
            .collection("tasks")
            .order(by: "priority", descending: true)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching tasks: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No documents found.")
                    self.tasks = []
                    return
                }
                
                self.tasks = documents.compactMap { document -> Task2? in
                    do {
                        return try document.data(as: Task2.self)
                    } catch {
                        print("Failed to decode task: \(error)")
                        return nil
                    }
                }
                print("Tasks loaded: \(self.tasks.count) task(s) found for user \(userId)")
            }
    }
    
    func addTask(task: Task2) {
        guard let userId = userId else {
            print("Cannot add task: No authenticated user")
            return
        }
        
        do {
            _ = try db.collection("users")
                .document(userId)
                .collection("tasks")
                .addDocument(from: task)
            print("Task added: \(task.taskDescription) for user \(userId)")
        } catch {
            print("Error adding task: \(error)")
        }
    }
    
    func updateTask(task: Task2) {
        guard let userId = userId else {
            print("Cannot update task: No authenticated user")
            return
        }
        
        guard let taskID = task.id else {
            print("Task has no ID; cannot update.")
            return
        }
        
        do {
            try db.collection("users")
                .document(userId)
                .collection("tasks")
                .document(taskID)
                .setData(from: task, merge: true)
            print("Task updated: \(task.taskDescription) for user \(userId)")
        } catch {
            print("Error updating task: \(error)")
        }
    }
    
    func deleteTask(taskID: String) {
        guard let userId = userId else {
            print("Cannot delete task: No authenticated user")
            return
        }
        
        db.collection("users")
            .document(userId)
            .collection("tasks")
            .document(taskID)
            .delete { error in
                if let error = error {
                    print("Error deleting task \(taskID): \(error)")
                } else {
                    print("Task deleted: \(taskID) for user \(userId)")
                }
            }
    }
}


// MARK: - Models/Priority.swift
import SwiftUI

enum Priority: Int16, CaseIterable {
    case low = 0, normal = 1, high = 2

    var title: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return .blue
        case .normal: return .indigo
        case .high: return .red
        }
    }

    var icon: String {
        switch self {
        case .low: return "arrow.down.circle.fill"
        case .normal: return "equal.circle.fill"
        case .high: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Services/SpeechRecognizer.swift
import Speech
import SwiftUI
import AVFoundation

class SpeechRecognizer: ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var authorizationStatus = SFSpeechRecognizerAuthorizationStatus.notDetermined

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        requestAuthorization()
    }

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                print("Speech recognition authorization status: \(status.rawValue)")
            }
        }
    }

    func startRecording() throws {
        guard authorizationStatus == .authorized else {
            throw NSError(domain: "SpeechRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        }
        resetRecording()
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                    print("Transcribed text: \(result.bestTranscription.formattedString)")
                }
                if let error = error {
                    print("Speech recognition error: \(error)")
                    self?.stopRecording()
                }
            }
        }
        isRecording = true
        print("Started recording.")
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        resetRecording()
        isRecording = false
        print("Stopped recording.")
    }

    private func resetRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
}

// MARK: - Services/TaskProcessor.swift
import Foundation
import FirebaseFirestore

class TaskProcessor: ObservableObject {
    private let geminiAPIKey = "AIzaSyBRW4kL382OkssfDRZsSWJi2WnCn1Xw5-U" // Replace with your actual key
    let firebaseService: FirebaseService

    init(firebaseService: FirebaseService) {
        self.firebaseService = firebaseService
    }

    struct TaskDict: Codable {
        let task: String
        let category: String
    }

    struct GeminiResponse: Codable {
        let tasks: [TaskDict]
    }

    func processSpeech(_ text: String) async throws {
        let prompt = """
        Extract actionable tasks from the following text.
        Categorize each task.

        Respond with a JSON in the following format:
        {
          "tasks": [
            {"task": "Task Description", "category": "Task Category"},
            {"task": "Another Task Description", "category": "Another Task Category"}
          ]
        }
        Text to process: \(text)
        """

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\(geminiAPIKey)") else {
            throw NSError(domain: "TaskProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw NSError(domain: "TaskProcessor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body to JSON"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw Gemini API Response:\n\(rawResponse)")
            }

            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError(domain: "TaskProcessor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response to JSON"])
            }
            guard let candidates = jsonResponse["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let aiTextResponse = firstPart["text"] as? String else {
                throw NSError(domain: "TaskProcessor", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unexpected JSON structure in response"])
            }

            // Remove markdown formatting (```json and ```)
            var cleanedResponse = aiTextResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedResponse.hasPrefix("```json") {
                cleanedResponse = cleanedResponse.replacingOccurrences(of: "```json", with: "")
            }
            if cleanedResponse.hasSuffix("```") {
                cleanedResponse = cleanedResponse.replacingOccurrences(of: "```", with: "")
            }
            cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Cleaned AI Response:\n\(cleanedResponse)")

            guard let aiData = cleanedResponse.data(using: .utf8) else {
                throw NSError(domain: "TaskProcessor", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to convert AI response to data"])
            }

            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: aiData)
            print("Gemini response decoded: \(geminiResponse)")

            await MainActor.run {
                let timestamp = Timestamp()
                for taskDict in geminiResponse.tasks {
                    let newTask = Task2(
                        taskDescription: taskDict.task,
                        category: taskDict.category,
                        isCompleted: false,
                        timestamp: timestamp,
                        priority: Priority.normal.rawValue,
                        notes: ""
                    )
                    firebaseService.addTask(task: newTask)
                    print("New task added from speech: \(newTask.taskDescription)")
                }
            }
        } catch {
            print("Gemini API error: \(error)")
            throw error
        }
    }
}

// MARK: - Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var taskProcessor: TaskProcessor
    @StateObject private var authService = AuthenticationService()

    @State private var isProcessing = false
    @State private var showingTaskDetail = false
    @State private var selectedTask: Task2?
    @State private var showingFilters = false
    @State private var selectedCategory: String?
    @State private var selectedPriority: Priority?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private var availableCategories: [String] {
        Array(Set(firebaseService.tasks.map { $0.category })).sorted()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    CategoryScrollView(categories: availableCategories, selectedCategory: $selectedCategory)
                    TaskListView(selectedCategory: selectedCategory,
                                 selectedPriority: selectedPriority,
                                 selectedTask: $selectedTask,
                                 showingTaskDetail: $showingTaskDetail)
                    Spacer()
                    RecordingButton(isRecording: speechRecognizer.isRecording,
                                    isProcessing: isProcessing,
                                    action: handleRecordingTap)
                }
//                RecordingButton(isRecording: speechRecognizer.isRecording,
//                                isProcessing: isProcessing,
//                                action: handleRecordingTap)
            }
            .navigationTitle("Voice Tasks")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingTaskDetail) {
                if let task = selectedTask {
                    TaskDetailView(task: task)
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterView(selectedCategory: $selectedCategory,
                           selectedPriority: $selectedPriority)
                    .presentationDetents([.medium])
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .environmentObject(firebaseService)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                showingFilters = true
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button(role: .destructive) {
                    clearCompletedTasks()
                } label: {
                    Label("Clear Completed", systemImage: "trash")
                }
                
                Button {
                    clearFilters()
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
                
                Button(role: .destructive) {
                    do {
                        try authService.signOut()
                    } catch {
                        errorMessage = error.localizedDescription
                        showingErrorAlert = true
                    }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }
    
    @MainActor
    private func handleRecordingTap() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            isProcessing = true
            
            Task {
                await processSpeechToTasks()
            }
            
        } else {
            do {
                try speechRecognizer.startRecording()
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                showingErrorAlert = true
                print("Error starting recording: \(error)")
            }
        }
    }
    
    @MainActor
    func processSpeechToTasks() async {
        do {
            try await taskProcessor.processSpeech(speechRecognizer.transcribedText)
            isProcessing = false
            print("Speech processed successfully.")
        } catch {
            errorMessage = "Task processing failed: \(error.localizedDescription)"
            showingErrorAlert = true
            isProcessing = false
            print("Error processing speech: \(error)")
        }
    }
    
    private func clearCompletedTasks() {
        let completedTasks = firebaseService.tasks.filter { $0.isCompleted }
        for task in completedTasks {
            if let taskID = task.id {
                firebaseService.deleteTask(taskID: taskID)
                print("Deleted task with ID: \(taskID)")
            }
        }
    }
    
    private func clearFilters() {
        selectedCategory = nil
        selectedPriority = nil
        print("Filters cleared.")
    }
}

// MARK: - Views/CategoryScrollView.swift
import SwiftUI

struct CategoryScrollView: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryChip(category: category,
                                 isSelected: selectedCategory == category,
                                 onTap: { toggleCategory(category) })
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private func toggleCategory(_ category: String) {
        selectedCategory = (selectedCategory == category) ? nil : category
        print("Category selected: \(selectedCategory ?? "None")")
    }
}

// MARK: - Views/TaskListView.swift
import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    let selectedCategory: String?
    let selectedPriority: Priority?
    @Binding var selectedTask: Task2?
    @Binding var showingTaskDetail: Bool
    
    var body: some View {
        List {
            ForEach(Priority.allCases, id: \.self) { priority in
                if let priorityTasks = filteredTasks(for: priority), !priorityTasks.isEmpty {
                    Section {
                        ForEach(priorityTasks) { task in
                            TaskRowView(task: task)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteTask(task)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        selectedTask = task
                                        showingTaskDetail = true
                                        print("Editing task: \(task.taskDescription)")
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    } header: {
                        Label(priority.title, systemImage: priority.icon)
                            .foregroundColor(priority.color)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func filteredTasks(for priority: Priority) -> [Task2]? {
        let priorityTasks = firebaseService.tasks.filter { Priority(rawValue: $0.priority) == priority }
        let categoryFilteredTasks = selectedCategory.map { category in
            priorityTasks.filter { $0.category == category }
        } ?? priorityTasks
        let finalFilteredTasks = selectedPriority.map { priority in
            categoryFilteredTasks.filter { Priority(rawValue: $0.priority) == priority }
        } ?? categoryFilteredTasks
        return finalFilteredTasks.isEmpty ? nil : finalFilteredTasks
    }
    
    private func deleteTask(_ task: Task2) {
        guard let taskID = task.id else { return }
        firebaseService.deleteTask(taskID: taskID)
        print("Task deleted: \(task.taskDescription)")
    }
}

// MARK: - Views/TaskRowView.swift
import SwiftUI

struct TaskRowView: View {
    @State var task: Task2
    @EnvironmentObject var firebaseService: FirebaseService

    var body: some View {
        HStack {
            Button {
                var updatedTask = task
                updatedTask.isCompleted.toggle()
                firebaseService.updateTask(task: updatedTask)
                task = updatedTask
                print("Task '\(task.taskDescription)' marked as \(task.isCompleted ? "completed" : "incomplete").")
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)
            Text(task.taskDescription)
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .gray : .primary)
            Spacer()
            Text(task.category)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Views/TaskDetailView.swift
import SwiftUI
import FirebaseFirestore

struct TaskDetailView: View {
    @State var task: Task2
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firebaseService: FirebaseService

    @State private var taskDescription: String = ""
    @State private var category: String = ""
    @State private var priority: Priority = .normal
    @State private var notes: String = ""
    @State private var dueDate: Date?
    @State private var isDueDateEnabled: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Description", text: $taskDescription)
                    TextField("Category", text: $category)
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) {
                            Text($0.title).tag($0)
                        }
                    }
                    Toggle(isOn: $isDueDateEnabled) { Text("Set Due Date") }
                    if isDueDateEnabled {
                        DatePicker("Due Date", selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    }
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        print("Task editing canceled.")
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                        print("Task saved: \(taskDescription)")
                        dismiss()
                    }
                }
            }
            .onAppear {
                taskDescription = task.taskDescription
                category = task.category
                priority = Priority(rawValue: task.priority) ?? .normal
                notes = task.notes ?? ""
                dueDate = task.dueDate?.dateValue()
                isDueDateEnabled = dueDate != nil
                print("Loaded task details for: \(task.taskDescription)")
            }
        }
    }

    private func saveTask() {
        var updatedTask = task
        updatedTask.taskDescription = taskDescription
        updatedTask.category = category
        updatedTask.priority = priority.rawValue
        updatedTask.notes = notes
        updatedTask.dueDate = isDueDateEnabled ? Timestamp(date: dueDate ?? Date()) : nil
        firebaseService.updateTask(task: updatedTask)
        print("Updated task: \(updatedTask.taskDescription)")
    }
}

// MARK: - Views/FilterView.swift
import SwiftUI

struct FilterView: View {
    @Binding var selectedCategory: String?
    @Binding var selectedPriority: Priority?

    var body: some View {
        Form {
            Section("Category") {
                List {
                    Button {
                        selectedCategory = nil
                        print("Filter: All categories selected.")
                    } label: {
                        HStack {
                            Text("All")
                            Spacer()
                            if selectedCategory == nil { Image(systemName: "checkmark") }
                        }
                    }
                    ForEach(["Work", "Personal", "Errands"], id: \.self) { category in
                        Button {
                            selectedCategory = category
                            print("Filter: Selected category \(category).")
                        } label: {
                            HStack {
                                Text(category)
                                Spacer()
                                if selectedCategory == category { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
            Section("Priority") {
                Picker("Priority", selection: $selectedPriority) {
                    Text("All Priorities").tag(nil as Priority?)
                    ForEach(Priority.allCases, id: \.self) { priority in
                        Text(priority.title).tag(priority as Priority?)
                    }
                }
                .onChange(of: selectedPriority) { newValue in
                    print("Filter: Selected priority \(newValue?.title ?? "All").")
                }
            }
        }
    }
}

// MARK: - Views/CategoryChip.swift
import SwiftUI

struct CategoryChip: View {
    let category: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(category)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Views/RecordingButton.swift
import SwiftUI

struct RecordingButton: View {
    let isRecording: Bool
    let isProcessing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                .font(.system(size: 50))
                .foregroundColor(isRecording ? .red : .blue)
                .overlay {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
        }
    }
}


// MARK: - Services/AuthenticationService.swift
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

class AuthenticationService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            DispatchQueue.main.async {
                self.user = result.user
                self.isAuthenticated = true
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    func signUp(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            DispatchQueue.main.async {
                self.user = result.user
                self.isAuthenticated = true
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.user = nil
                self.isAuthenticated = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
}

// MARK: - Views/AuthenticationView.swift
struct AuthenticationView: View {
    @StateObject private var authService = AuthenticationService()
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(isSignUp ? "Sign Up" : "Sign In") {
                    Task {
                        do {
                            if isSignUp {
                                try await authService.signUp(email: email, password: password)
                            } else {
                                try await authService.signIn(email: email, password: password)
                            }
                        } catch {
                            showAlert = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button(isSignUp ? "Already have an account? Sign In" : "Need an account? Sign Up") {
                    isSignUp.toggle()
                }
            }
            .padding()
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .alert("Authentication Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authService.errorMessage ?? "An error occurred")
            }
        }
    }
}

// MARK: - Views/RootView.swift
struct RootView: View {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var firebaseService = FirebaseService()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                ContentView()
                    .environmentObject(firebaseService)
                    .environmentObject(TaskProcessor(firebaseService: firebaseService))
                    .environmentObject(authService)
            } else {
                AuthenticationView()
                    .environmentObject(authService)
            }
        }
    }
}


