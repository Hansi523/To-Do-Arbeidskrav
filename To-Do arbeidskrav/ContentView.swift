//
//  ContentView.swift
//  To-Do arbeidskrav
//
//  Created by Hans Inge Paulshus on 28/09/2025.
//

import SwiftUI
import Combine

// MARK: - Modellering

enum Status: String, CaseIterable, Identifiable {
    case notStarted = "Ikke startet enda"
    case inProgress = "Pågår"
    case completed = "Fullført"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed:  return .green
        }
    }

    var symbolName: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "clock"
        case .completed:  return "checkmark.circle.fill"
        }
    }
}

struct Task: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var description: String
    var dueDate: Date
    var status: Status
}

// MARK: - Tilstand (@ObservedObject via store)

final class TaskStore: ObservableObject {
    @Published var tasks: [Task]

    init(tasks: [Task] = []) {
        if tasks.isEmpty {
            // Eksempeldata
            self.tasks = [
                Task(title: "Skriv prosjektbeskrivelse",
                     description: "Lag en kort beskrivelse av appens mål og funksjoner.",
                     dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                     status: .inProgress),
                Task(title: "Design listevisning",
                     description: "Bruk List og lag en pen radvisning med status-ikon.",
                     dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                     status: .notStarted),
                Task(title: "Implementer detaljvisning",
                     description: "Vis beskrivelse, frist og status. Tillat endring av status.",
                     dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
                     status: .notStarted),
                Task(title: "Poler design og legg til filtrering",
                     description: "Valgfritt bonus: filter, sortering, fremdriftsindikator.",
                     dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date(),
                     status: .completed)
            ]
        } else {
            self.tasks = tasks
        }
    }
}

// MARK: - Filtrering og sortering

private enum FilterOption: Hashable, Identifiable {
    case all
    case status(Status)

    var id: String {
        switch self {
        case .all: return "all"
        case .status(let s): return "status-\(s.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .all: return "Alle"
        case .status(let s): return s.rawValue
        }
    }
}

private enum SortOrder: String, CaseIterable, Identifiable {
    case dueDateAsc = "Frist ↑"
    case dueDateDesc = "Frist ↓"

    var id: String { rawValue }
}

// MARK: - Hovedvisning

struct ContentView: View {
    @StateObject private var store = TaskStore()

    @State private var showAddSheet = false
    @State private var filter: FilterOption = .all
    @State private var sortOrder: SortOrder = .dueDateAsc

    private var displayedIndices: [Int] {
        let indices = store.tasks.indices.filter { idx in
            switch filter {
            case .all:
                return true
            case .status(let s):
                return store.tasks[idx].status == s
            }
        }
        .sorted { lhs, rhs in
            let l = store.tasks[lhs]
            let r = store.tasks[rhs]
            switch sortOrder {
            case .dueDateAsc:
                return l.dueDate < r.dueDate
            case .dueDateDesc:
                return l.dueDate > r.dueDate
            }
        }
        return indices
    }

    private var completionProgress: Double {
        let total = store.tasks.count
        guard total > 0 else { return 0 }
        let completed = store.tasks.filter { $0.status == .completed }.count
        return Double(completed) / Double(total)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Bonus: Filtrering
                filterPicker

                // Bonus: Fremdriftsindikator
                if store.tasks.isEmpty == false {
                    progressHeader
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }

                List {
                    ForEach(displayedIndices, id: \.self) { idx in
                        let task = store.tasks[idx]
                        NavigationLink {
                            TaskDetailView(task: bindingForIndex(idx))
                        } label: {
                            TaskRow(task: task)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if task.status != .completed {
                                Button {
                                    withAnimation {
                                        store.tasks[idx].status = .completed
                                    }
                                } label: {
                                    Label("Fullfør", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            } else {
                                Button {
                                    withAnimation {
                                        store.tasks[idx].status = .notStarted
                                    }
                                } label: {
                                    Label("Angre", systemImage: "arrow.uturn.left")
                                }
                                .tint(.orange)
                            }

                            Button(role: .destructive) {
                                deleteByIndices([idx])
                            } label: {
                                Label("Slett", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Oppgaver")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sorter", selection: $sortOrder) {
                            ForEach(SortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Label("Sorter", systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sorter")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Legg til", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                TaskFormView { newTask in
                    withAnimation {
                        store.tasks.append(newTask)
                    }
                }
            }

            // Detaljplaceholder for iPad/multivindu
            Text("Velg en oppgave")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Delvisninger

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([FilterOption.all] + Status.allCases.map { .status($0) }) { option in
                    let isSelected = option == filter
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            filter = option
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if case .status(let s) = option {
                                Image(systemName: s.symbolName)
                                    .foregroundStyle(s.color)
                            }
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Filter \(option.title)")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Fremdrift", systemImage: "chart.bar.fill")
                    .font(.headline)
                Spacer()
                Text(progressText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: completionProgress)
                .tint(.green)
        }
    }

    private var progressText: String {
        let total = store.tasks.count
        let completed = store.tasks.filter { $0.status == .completed }.count
        return "\(completed) av \(total) fullført"
    }

    private func bindingForIndex(_ index: Int) -> Binding<Task> {
        Binding(
            get: { store.tasks[index] },
            set: { store.tasks[index] = $0 }
        )
    }

    private func delete(_ offsets: IndexSet) {
        // Map synlige offsets til faktiske indekser i store.tasks
        let storeIndices = offsets.map { displayedIndices[$0] }.sorted(by: >)
        deleteByIndices(storeIndices)
    }

    private func deleteByIndices(_ indices: [Int]) {
        for i in indices.sorted(by: >) {
            store.tasks.remove(at: i)
        }
    }
}

// MARK: - Radvisning

private struct TaskRow: View {
    let task: Task

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.status.symbolName)
                .foregroundStyle(task.status.color)
                .imageScale(.large)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(task.status.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(task.dueDate, style: .date)
                    .font(.subheadline)
                Text(task.dueDate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detaljvisning

private struct TaskDetailView: View {
    @Binding var task: Task

    var body: some View {
        Form {
            Section("Oppgave") {
                TextField("Tittel", text: $task.title)
                TextField("Beskrivelse", text: $task.description, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Frist") {
                DatePicker("Dato", selection: $task.dueDate, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Status") {
                Picker("Status", selection: $task.status) {
                    ForEach(Status.allCases) { s in
                        HStack {
                            Image(systemName: s.symbolName)
                            Text(s.rawValue)
                        }
                        .tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Detaljer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Skjema for ny oppgave (Bonus)

private struct TaskFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var dueDate: Date = Date()
    @State private var status: Status = .notStarted

    var onSave: (Task) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Oppgave") {
                    TextField("Tittel", text: $title)
                    TextField("Beskrivelse", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Frist") {
                    DatePicker("Dato", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(Status.allCases) { s in
                            HStack {
                                Image(systemName: s.symbolName)
                                Text(s.rawValue)
                            }
                            .tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Ny oppgave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lagre") {
                        let newTask = Task(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                           description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                           dueDate: dueDate,
                                           status: status)
                        onSave(newTask)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
