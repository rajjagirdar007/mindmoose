//// MARK: - VoiceTasksApp.swift
//import SwiftUI
//import Firebase
//
//
//@main
//struct VoiceTasksApp: App {
//    
//    
//    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
//    @StateObject var firebaseService = FirebaseService()
//
//
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//                .environmentObject(firebaseService)
//                .environmentObject(TaskProcessor(firebaseService: firebaseService)) // Pass the initialized TaskProcessor
//                .tint(.indigo)
//        }
//    }
//}
//
//import FirebaseAppCheck
//
//class AppDelegate: NSObject, UIApplicationDelegate {
//    func application(_ application: UIApplication,
//                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
//        
//        // IMPORTANT: Use this for debug builds only
//        #if DEBUG
//        let providerFactory = AppCheckDebugProviderFactory()
//        AppCheck.setAppCheckProviderFactory(providerFactory)
//        #endif
//        
//        FirebaseApp.configure()
//        return true
//    }
//}
//
//
//// MARK: - Task.xcdatamodeld
///*
// Entity: TaskEntity
// Attributes:
// - id: UUID
// - taskDescription: String
// - category: String
// - isCompleted: Boolean
// - timestamp: Date
// - priority: Integer 16 (default: 0)
// - notes: String (optional)
// - dueDate: Date (optional)
// */
//
//// MARK: - PersistenceController.swift
//import CoreData
//import UIKit // Import UIKit for UIApplication
//
//class PersistenceController {
//    static let shared = PersistenceController()
//
//    let container: NSPersistentContainer
//
//    init(inMemory: Bool = false) {
//        container = NSPersistentContainer(name: "TaskEntity")
//
//        if inMemory {
//            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
//        }
//
//        container.loadPersistentStores { description, error in
//            if let error = error {
//                fatalError("Failed to load Core Data: \(error.localizedDescription)")
//            }
//        }
//
//        container.viewContext.automaticallyMergesChangesFromParent = true
//        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
//
//        // Enable automatic saving - using performBackgroundTask for efficiency
//        NotificationCenter.default.addObserver(
//            forName: UIApplication.willResignActiveNotification,
//            object: nil,
//            queue: .main // Ensure this is on the main queue as it's UI related
//        ) { [weak self] _ in
//            self?.saveContextInBackground() // Use background context for saving
//        }
//    }
//
//    // Save context in background to prevent blocking the main thread
//    private func saveContextInBackground() {
//        container.performBackgroundTask { backgroundContext in
//            if backgroundContext.hasChanges {
//                do {
//                    try backgroundContext.save()
//                } catch {
//                    print("Error saving context in background: \(error)")
//                }
//            }
//        }
//    }
//
//    func save() { // Keep this for explicit saves if needed, still uses main context
//        let context = container.viewContext
//        if context.hasChanges {
//            do {
//                try context.save()
//            } catch {
//                print("Error saving context: \(error)")
//            }
//        }
//    }
//}
//
//// MARK: - Extensions/TaskEntity+Helper.swift
//import CoreData
//// MARK: - Models/Task.swift (Firebase Model)
//
//import FirebaseFirestore
//
//struct Task: Identifiable, Codable {
//    @DocumentID var id: String? // DocumentID for Firestore auto-ID or your UUID
//    var taskDescription: String
//    var category: String
//    var isCompleted: Bool
//    var timestamp: Timestamp // Firestore Timestamp
//    var priority: Int16 // Match Priority enum rawValue type
//    var notes: String?
//    var dueDate: Timestamp? // Optional Firestore Timestamp
//
//    // For Identifiable conformance
//    // Note: Firestore DocumentID is optional, so we use UUID() if nil for SwiftUI lists
//    var documentID: String {
//        return id ?? UUID().uuidString
//    }
//
//    enum CodingKeys: String, CodingKey {
//        case id
//        case taskDescription
//        case category
//        case isCompleted
//        case timestamp
//        case priority
//        case notes
//        case dueDate
//    }
//
//    // Initialize from Core Data TaskEntity for migration (optional)
//
//    // Default initializer for creating new tasks
//    init(id: String? = nil, taskDescription: String, category: String, isCompleted: Bool, timestamp: Timestamp, priority: Int16, notes: String? = nil, dueDate: Timestamp? = nil) {
//        self.id = id
//        self.taskDescription = taskDescription
//        self.category = category
//        self.isCompleted = isCompleted
//        self.timestamp = timestamp
//        self.priority = priority
//        self.notes = notes
//        self.dueDate = dueDate
//    }
//}
//
//
//// MARK: - Services/FirebaseService.swift
//import FirebaseFirestore
//import Combine // For Publishers if you want to use Combine
//
//class FirebaseService: ObservableObject {
//    @Published var tasks: [Task] = []
//
//    private let db = Firestore.firestore()
//    private var listener: ListenerRegistration? = nil
//
//    init() {
//        loadTasks() // Automatically load tasks when FirebaseService is initialized
//    }
//
//    deinit {
//        listener?.remove() // Stop listening when FirebaseService is deallocated
//    }
//
//    func loadTasks() {
//        listener = db.collection("tasks")
//            .order(by: "priority", descending: true)
//            .order(by: "timestamp", descending: true)
//            .addSnapshotListener { querySnapshot, error in
//                if let error = error {
//                    print("Error fetching tasks: \(error)")
//                    return
//                }
//
//                guard let documents = querySnapshot?.documents else {
//                    print("No documents found")
//                    self.tasks = []
//                    return
//                }
//
//                self.tasks = documents.compactMap { document -> Task? in
//                    do {
//                        return try document.data(as: Task.self)
//                    } catch {
//                        print("Failed to decode task from document: \(error)")
//                        return nil
//                    }
//                }
//            }
//    }
//
//    func addTask(task: Task) {
//        do {
//            _ = try db.collection("tasks").addDocument(from: task)
//        } catch {
//            print("Error adding task: \(error)")
//        }
//    }
//
//    func updateTask(task: Task) {
//        guard let taskID = task.id else {
//            print("Task has no ID, cannot update.")
//            return
//        }
//        do {
//            try db.collection("tasks").document(taskID).setData(from: task, merge: true) // Use merge: true to update only provided fields
//        } catch {
//            print("Error updating task: \(error)")
//        }
//    }
//
//
//    func deleteTask(taskID: String) {
//        db.collection("tasks").document(taskID).delete() { error in
//            if let error = error {
//                print("Error removing document: \(error)")
//            } else {
//                print("Document successfully removed!")
//            }
//        }
//    }
//
//    // Example of filtering and querying (can be expanded)
//    func fetchTasksByCategory(category: String) {
//        db.collection("tasks")
//            .whereField("category", isEqualTo: category)
//            .getDocuments { (querySnapshot, error) in
//                if let error = error {
//                    print("Error getting documents: \(error)")
//                } else {
//                    self.tasks = querySnapshot!.documents.compactMap { document -> Task? in
//                        do {
//                            return try document.data(as: Task.self)
//                        } catch {
//                            print("Failed to decode task from document: \(error)")
//                            return nil
//                        }
//                    }
//                }
//            }
//    }
//
//    func fetchTasksByPriority(priority: Priority) {
//        db.collection("tasks")
//            .whereField("priority", isEqualTo: priority.rawValue)
//            .getDocuments { (querySnapshot, error) in
//                if let error = error {
//                    print("Error getting documents: \(error)")
//                } else {
//                    self.tasks = querySnapshot!.documents.compactMap { document -> Task? in
//                        do {
//                            return try document.data(as: Task.self)
//                        } catch {
//                            print("Failed to decode task from document: \(error)")
//                            return nil
//                        }
//                    }
//                }
//            }
//    }
//
//    // ... Add more querying methods as needed (e.g., by completion status, date range)
//}
//
//
//
//// MARK: - Models/Priority.swift
//import SwiftUI
//
//enum Priority: Int16, CaseIterable { // Changed to Int16 to match Core Data attribute type
//    case low = 0
//    case normal = 1
//    case high = 2
//
//    var title: String {
//        switch self {
//        case .low: return "Low"
//        case .normal: return "Normal"
//        case .high: return "High"
//        }
//    }
//
//    var color: Color {
//        switch self {
//        case .low: return .blue
//        case .normal: return .indigo
//        case .high: return .red
//        }
//    }
//
//    var icon: String {
//        switch self {
//        case .low: return "arrow.down.circle.fill"
//        case .normal: return "equal.circle.fill"
//        case .high: return "exclamationmark.circle.fill"
//        }
//    }
//}
//
//// MARK: - Services/SpeechRecognizer.swift
//import Speech
//import SwiftUI
//
//class SpeechRecognizer: ObservableObject {
//    @Published var isRecording = false
//    @Published var transcribedText = ""
//    @Published var authorizationStatus = SFSpeechRecognizerAuthorizationStatus.notDetermined
//
//    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
//    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
//    private var recognitionTask: SFSpeechRecognitionTask?
//    private let audioEngine = AVAudioEngine()
//
//    init() {
//        requestAuthorization()
//    }
//
//    func requestAuthorization() {
//        SFSpeechRecognizer.requestAuthorization { status in
//            DispatchQueue.main.async {
//                self.authorizationStatus = status
//            }
//        }
//    }
//
//    func startRecording() throws {
//        guard authorizationStatus == .authorized else {
//            throw NSError(domain: "SpeechRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
//        }
//
//        // Reset previous recording if any
//        resetRecording()
//
//        // Configure audio session
//        let audioSession = AVAudioSession.sharedInstance()
//        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
//        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
//
//        // Create and configure recognition request
//        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
//        recognitionRequest?.shouldReportPartialResults = true
//
//        // Configure audio engine
//        let inputNode = audioEngine.inputNode
//        let recordingFormat = inputNode.outputFormat(forBus: 0)
//        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
//            self.recognitionRequest?.append(buffer)
//        }
//
//        audioEngine.prepare()
//        try audioEngine.start()
//
//        // Start recognition
//        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, error in
//            DispatchQueue.main.async {
//                if let result = result {
//                    self.transcribedText = result.bestTranscription.formattedString
//                }
//                if error != nil {
//                    self.stopRecording()
//                }
//            }
//        }
//
//        isRecording = true
//    }
//
//    func stopRecording() {
//        audioEngine.stop()
//        audioEngine.inputNode.removeTap(onBus: 0)
//        recognitionRequest?.endAudio()
//
//        resetRecording()
//        isRecording = false
//    }
//
//    private func resetRecording() {
//        recognitionTask?.cancel()
//        recognitionTask = nil
//        recognitionRequest = nil
//    }
//}
//
//// MARK: - Services/TaskProcessor.swift
//import CoreData
//import Foundation
//
//class TaskProcessor: ObservableObject {
//    private let geminiAPIKey = "YOUR_GEMINI_API_KEY" // Replace with your actual Gemini API key
//    let firebaseService: FirebaseService // Changed to let and removed @EnvironmentObject
//
//    init(firebaseService: FirebaseService) {
//        self.firebaseService = firebaseService
//    }
//
//    struct TaskDict: Codable {
//        let task: String
//        let category: String
//    }
//
//    struct GeminiResponse: Codable {
//        let tasks: [TaskDict]
//    }
//
//
//    func processSpeech(_ text: String) async throws {
//        let prompt = """
//        Extract actionable tasks from the following text.
//        Categorize each task.
//
//        Respond with a JSON in the following format:
//        {
//        "tasks": [
//        {"task": "Task Description", "category": "Task Category"},
//        {"task": "Another Task Description", "category": "Another Task Category"}
//        ]
//        }
//        Text to process: \(text)
//        """
//
//        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\(geminiAPIKey)") else {
//            throw NSError(domain: "TaskProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
//        }
//
//        let requestBody: [String: Any] = [
//            "contents": [
//                [
//                    "parts": [
//                        ["text": prompt]
//                    ]
//                ]
//            ]
//        ]
//
//        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
//            throw NSError(domain: "TaskProcessor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body to JSON"])
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = jsonData
//
//        do {
//            let (data, _) = try await URLSession.shared.data(for: request)
//
//            // Debugging: Print the raw response data
//            if let rawResponse = String(data: data, encoding: .utf8) {
//                print("Raw Gemini API Response:\n\(rawResponse)")
//            }
//
//            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
//                throw NSError(domain: "TaskProcessor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response to JSON"])
//            }
//
//            guard let candidates = jsonResponse["candidates"] as? [[String: Any]] else {
//                throw NSError(domain: "TaskProcessor", code: 5)
//            }
//            guard let firstCandidate = candidates.first else {
//                throw NSError(
//                    domain: "TaskProcessor",
//                    code: 5,
//                    userInfo: [NSLocalizedDescriptionKey: "Missing 'candidates' in JSON response"]
//                )
//            }
//            guard let content = firstCandidate["content"] as? [String: Any] else {
//                throw NSError(domain: "TaskProcessor", code: 7)
//            }
//            guard let parts = content["parts"] as? [[String: Any]] else {
//                throw NSError(domain: "TaskProcessor", code: 8)
//            }
//            guard let firstPart = parts.first else {
//                throw NSError(domain: "TaskProcessor", code: 9)
//            }
//            guard let aiTextResponse = firstPart["text"] as? String else {
//                throw NSError(domain: "TaskProcessor", code: 10)
//            }
//
//
////             Convert the string response to Data for JSON decoding
//            guard let aiData = aiTextResponse.data(using: .utf8) else {
//                throw NSError(domain: "TaskProcessor", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to convert AI response to data"])
//            }
//
////             Attempt to decode the JSON data into your GeminiResponse struct
//            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: aiData)
//
//            await MainActor.run {
//                  let timestamp = Timestamp() // Current Firestore timestamp
//                  for taskDict in geminiResponse.tasks {
//                      let newTask = Task(
//                          taskDescription: taskDict.task,
//                          category: taskDict.category,
//                          isCompleted: false,
//                          timestamp: timestamp,
//                          priority: Priority.normal.rawValue, // Default priority
//                          notes: "" // No notes from Gemini
//                      )
//                      firebaseService.addTask(task: newTask) // Use injected FirebaseService instance
//                  }
//              }
//
//        } catch {
//            print("Gemini API error: \(error)")
//            throw error // Re-throw the error to be handled by the caller
//        }
//    }
//    
//}
//
//
//// MARK: - Views/ContentView.swift
//import SwiftUI
//import CoreData // Import CoreData
//// MARK: - Views/ContentView.swift (Firebase Version)
//import SwiftUI
//// MARK: - Views/ContentView.swift (Firebase Version)
//import SwiftUI
//struct ContentView: View {
//    @StateObject private var speechRecognizer = SpeechRecognizer()
//    @EnvironmentObject var firebaseService: FirebaseService
//    @EnvironmentObject var taskProcessor: TaskProcessor
//    
//    // Move state variables to struct level
//    @State private var isProcessing = false
//    @State private var showingTaskDetail = false
//    @State private var selectedTask: Task?
//    @State private var showingFilters = false
//    @State private var selectedCategory: String?
//    @State private var selectedPriority: Priority?
//    @State private var showingErrorAlert = false
//    @State private var errorMessage = ""
//    
//    // Computed property for categories
//    private var availableCategories: [String] {
//        Array(Set(firebaseService.tasks.map { $0.category })).sorted()
//    }
//    
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                VStack {
//                    // Categories ScrollView
//                    CategoryScrollView(
//                        categories: availableCategories,
//                        selectedCategory: $selectedCategory
//                    )
//                    
//                    // Task List
//                    TaskListView(
//                        selectedCategory: selectedCategory,
//                        selectedPriority: selectedPriority,
//                        selectedTask: $selectedTask,
//                        showingTaskDetail: $showingTaskDetail
//                    )
//                }
//                // Recording Button
//                RecordingButton(
//                    isRecording: speechRecognizer.isRecording,
//                    isProcessing: isProcessing,
//                    action: handleRecordingTap
//                )
//                
//                
//            }
//            .navigationTitle("Voice Tasks")
//            .toolbar {
//                toolbarContent
//            }
//            .sheet(isPresented: $showingTaskDetail) {
//                if let task = selectedTask {
//                    TaskDetailView(task: task)
//                }
//            }
//            .sheet(isPresented: $showingFilters) {
//                FilterView(
//                    selectedCategory: $selectedCategory,
//                    selectedPriority: $selectedPriority
//                )
//                .presentationDetents([.medium])
//            }
//            .alert("Error", isPresented: $showingErrorAlert) {
//                Button("OK", role: .cancel) {}
//            } message: {
//                Text(errorMessage)
//            }
//        }
//        .environmentObject(firebaseService)
//    }
//    
//    // MARK: - Toolbar Content
//    @ToolbarContentBuilder
//    private var toolbarContent: some ToolbarContent {
//        ToolbarItem(placement: .navigationBarLeading) {
//            Button {
//                showingFilters = true
//            } label: {
//                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
//            }
//        }
//        
//        ToolbarItem(placement: .navigationBarTrailing) {
//            Menu {
//                Button(role: .destructive) {
//                    clearCompletedTasks()
//                } label: {
//                    Label("Clear Completed", systemImage: "trash")
//                }
//                
//                Button {
//                    clearFilters()
//                } label: {
//                    Label("Clear Filters", systemImage: "xmark.circle")
//                }
//            } label: {
//                Label("More", systemImage: "ellipsis.circle")
//            }
//        }
//    }
//    
//    // MARK: - Helper Functions
//    @MainActor
//    private func handleRecordingTap() {
//        if speechRecognizer.isRecording {
//            speechRecognizer.stopRecording()
//            isProcessing = true
////            Task {
////                await processSpeechToTasks()
////            }
//        } else {
//            do {
//                try speechRecognizer.startRecording()
//            } catch {
//                errorMessage = "Failed to start recording: \(error.localizedDescription)"
//                showingErrorAlert = true
//            }
//        }
//    }
//    
//    @MainActor
//    private func processSpeechToTasks() async {
//        do {
//            try await taskProcessor.processSpeech(speechRecognizer.transcribedText)
//            isProcessing = false
//        } catch {
//            errorMessage = "Task processing failed: \(error.localizedDescription)"
//            showingErrorAlert = true
//            isProcessing = false
//        }
//    }
//    
//    private func clearCompletedTasks() {
//        let completedTasks = firebaseService.tasks.filter { $0.isCompleted }
//        for task in completedTasks {
//            if let taskID = task.id {
//                firebaseService.deleteTask(taskID: taskID)
//            }
//        }
//    }
//    
//    private func clearFilters() {
//        selectedCategory = nil
//        selectedPriority = nil
//    }
//}
//
//// MARK: - Supporting Views
//struct CategoryScrollView: View {
//    let categories: [String]
//    @Binding var selectedCategory: String?
//    
//    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 12) {
//                ForEach(categories, id: \.self) { category in
//                    CategoryChip(
//                        category: category,
//                        isSelected: selectedCategory == category,
//                        onTap: { toggleCategory(category) }
//                    )
//                }
//            }
//            .padding(.horizontal)
//        }
//        .padding(.vertical, 8)
//    }
//    
//    private func toggleCategory(_ category: String) {
//        selectedCategory = selectedCategory == category ? nil : category
//    }
//}
//
//struct TaskListView: View {
//    @EnvironmentObject var firebaseService: FirebaseService
//    let selectedCategory: String?
//    let selectedPriority: Priority?
//    @Binding var selectedTask: Task?
//    @Binding var showingTaskDetail: Bool
//    
//    var body: some View {
//        List {
//            ForEach(Priority.allCases, id: \.self) { priority in
//                if let priorityTasks = filteredTasks(for: priority), !priorityTasks.isEmpty {
//                    Section {
//                        ForEach(priorityTasks) { task in
//                            TaskRowView(task: task)
//                                .swipeActions(edge: .trailing) {
//                                    Button(role: .destructive) {
//                                        deleteTask(task)
//                                    } label: {
//                                        Label("Delete", systemImage: "trash")
//                                    }
//                                }
//                                .swipeActions(edge: .leading) {
//                                    Button {
//                                        selectedTask = task
//                                        showingTaskDetail = true
//                                    } label: {
//                                        Label("Edit", systemImage: "pencil")
//                                    }
//                                    .tint(.blue)
//                                }
//                        }
//                    } header: {
//                        Label(priority.title, systemImage: priority.icon)
//                            .foregroundColor(priority.color)
//                    }
//                }
//            }
//        }
//        .listStyle(.insetGrouped)
//    }
//    
//    private func filteredTasks(for priority: Priority) -> [Task]? {
//        let priorityTasks = firebaseService.tasks.filter { Priority(rawValue: $0.priority) == priority }
//        
//        let categoryFilteredTasks = selectedCategory.map { category in
//            priorityTasks.filter { $0.category == category }
//        } ?? priorityTasks
//        
//        let finalFilteredTasks = selectedPriority.map { priority in
//            categoryFilteredTasks.filter { Priority(rawValue: $0.priority) == priority }
//        } ?? categoryFilteredTasks
//        
//        return finalFilteredTasks.isEmpty ? nil : finalFilteredTasks
//    }
//    
//    private func deleteTask(_ task: Task) {
//        guard let taskID = task.id else { return }
//        firebaseService.deleteTask(taskID: taskID)
//    }
//}
//
//
//// MARK: - Views/TaskRowView.swift
//import SwiftUI
//// MARK: - Views/TaskRowView.swift (Firebase Version)
//import SwiftUI
//
//struct TaskRowView: View {
//    @State var task: Task // Now using Firebase Task struct, State to trigger view update on completion toggle
//    @EnvironmentObject var firebaseService: FirebaseService // Access FirebaseService from environment
//
//    var body: some View {
//        HStack {
//            Button {
//                var updatedTask = task // Create a mutable copy
//                updatedTask.isCompleted.toggle()
//                firebaseService.updateTask(task: updatedTask) // Update Firebase
//                task = updatedTask // Update local state to refresh view immediately
//            } label: {
//                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
//            }
//            .buttonStyle(.plain)
//
//            Text(task.taskDescription)
//                .strikethrough(task.isCompleted)
//                .foregroundColor(task.isCompleted ? .gray : .primary)
//            Spacer()
//            Text(task.category)
//                .font(.caption)
//                .foregroundColor(.secondary)
//        }
//    }
//}
//// MARK: - Views/TaskDetailView.swift
//import SwiftUI
//// MARK: - Views/TaskDetailView.swift (Firebase Version)
//import SwiftUI
//import FirebaseFirestore
//
//struct TaskDetailView: View {
//    @State var task: Task // Firebase Task
//    @Environment(\.dismiss) var dismiss
//    @EnvironmentObject var firebaseService: FirebaseService
//
//    @State private var taskDescription: String = ""
//    @State private var category: String = ""
//    @State private var priority: Priority = .normal
//    @State private var notes: String = ""
//    @State private var dueDate: Date?
//    @State private var isDueDateEnabled: Bool = false // State for toggle
//
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("Task Details") {
//                    TextField("Description", text: $taskDescription)
//                    TextField("Category", text: $category)
//                    Picker("Priority", selection: $priority) {
//                        ForEach(Priority.allCases, id: \.self) {
//                            Text($0.title).tag($0)
//                        }
//                    }
//                    Toggle(isOn: $isDueDateEnabled) {
//                        Text("Set Due Date")
//                    }
//                    if isDueDateEnabled {
//                        DatePicker("Due Date", selection: Binding(
//                            get: { dueDate ?? Date() }, // Provide a non-nil Date for DatePicker
//                            set: { dueDate = $0 }
//                        ), displayedComponents: .date)
//                        .datePickerStyle(.graphical)
//                    }
//                }
//
//                Section("Notes") {
//                    TextEditor(text: $notes)
//                        .frame(minHeight: 100)
//                }
//            }
//            .navigationTitle("Edit Task")
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                }
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Save") {
//                        saveTask()
//                        dismiss()
//                    }
//                }
//            }
//            .onAppear {
//                taskDescription = task.taskDescription
//                category = task.category
//                priority = Priority(rawValue: task.priority) ?? .normal
//                notes = task.notes ?? ""
//                dueDate = task.dueDate?.dateValue() // Convert Timestamp to Date
//                isDueDateEnabled = dueDate != nil // Initialize toggle based on existing due date
//            }
//        }
//    }
//
//    private func saveTask() {
//        var updatedTask = task // Create a mutable copy
//        updatedTask.taskDescription = taskDescription
//        updatedTask.category = category
//        updatedTask.priority = priority.rawValue
//        updatedTask.notes = notes
//        updatedTask.dueDate = isDueDateEnabled ? Timestamp(date: dueDate ?? Date()) : nil // Convert Date to Timestamp
//
//        firebaseService.updateTask(task: updatedTask)
//    }
//}
//
//// MARK: - Views/FilterView.swift
//import SwiftUI
//
//struct FilterView: View {
//    @Binding var selectedCategory: String?
//    @Binding var selectedPriority: Priority?
//
//    var body: some View {
//        Form {
//            Section("Category") {
//                List {
//                    Button {
//                        selectedCategory = nil
//                    } label: {
//                        HStack {
//                            Text("All")
//                            Spacer()
//                            if selectedCategory == nil {
//                                Image(systemName: "checkmark")
//                            }
//                        }
//                    }
//                    ForEach(["Work", "Personal", "Errands"], id: \.self) { category in
//                        Button {
//                            selectedCategory = category
//                        } label: {
//                            HStack {
//                                Text(category)
//                                Spacer()
//                                if selectedCategory == category {
//                                    Image(systemName: "checkmark")
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//
//            Section("Priority") {
//                Picker("Priority", selection: $selectedPriority) {
//                    Text("All Priorities").tag(nil as Priority?)
//                    ForEach(Priority.allCases, id: \.self) { priority in
//                        Text(priority.title).tag(priority as Priority?)
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Views/CategoryChip.swift
//import SwiftUI
//
//struct CategoryChip: View {
//    let category: String
//    let isSelected: Bool
//    let onTap: () -> Void
//
//    var body: some View {
//        Button(action: onTap) {
//            Text(category)
//                .padding(.horizontal, 12)
//                .padding(.vertical, 8)
//                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
//                .foregroundColor(isSelected ? .white : .primary)
//                .cornerRadius(20)
//        }
//    }
//}
//
//// MARK: - Views/RecordingButton.swift
//import SwiftUI
//
//struct RecordingButton: View {
//    let isRecording: Bool
//    let isProcessing: Bool
//    let action: () -> Void
//
//    var body: some View {
//        Button(action: action) {
//            Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
//                .font(.system(size: 50))
//                .foregroundColor(isRecording ? .red : .blue)
//                .overlay {
//                    if isProcessing {
//                        ProgressView()
//                            .scaleEffect(1.5)
//                            .tint(.white)
//                    }
//                }
//        }
//    }
//}
