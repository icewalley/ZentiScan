
import SwiftUI

struct ChecklistView: View {
    let code: String
    @StateObject private var api = APIManager.shared
    @State private var checkpoints: [Checkpoint] = []
    @State private var results: [Int: String] = [:] // ID -> Value (generic)
    @State private var statuses: [Int: String] = [:] // ID -> Status
    @State private var comments: [Int: String] = [:]
    
    // Status options
    let statusOptions = ["OK", "AVVIK", "IKKE VURDERT"]
    
    var body: some View {
        Form {
            Section(header: Text("Sjekkliste for \(code)")) {
                if checkpoints.isEmpty {
                    if api.isLoading {
                        ProgressView("Laster sjekkpunkter...")
                    } else if let error = api.errorMessage {
                        Text("Feil: \(error)").foregroundColor(.red)
                    } else {
                        Text("Ingen sjekkpunkter funnet.")
                    }
                } else {
                    ForEach(checkpoints) { point in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(point.text)
                                .font(.headline)
                            
                            if let desc = point.description {
                                Text(desc).font(.caption).foregroundColor(.secondary)
                            }
                            
                            Picker("Status", selection: binding(for: point.id, dict: $statuses, defaultVal: "OK")) {
                                ForEach(statusOptions, id: \.self) { opt in
                                    Text(opt).tag(opt)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            TextField("Verdi / Måling", text: binding(for: point.id, dict: $results, defaultVal: ""))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                            
                            TextField("Kommentar", text: binding(for: point.id, dict: $comments, defaultVal: ""))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            
            Section {
                Button(action: submit) {
                    if api.isLoading {
                        ProgressView()
                    } else {
                        Text("Send inn registrering")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.blue)
                .disabled(checkpoints.isEmpty || api.isLoading)
            }
        }
        .onAppear {
            loadCheckpoints()
        }
    }
    
    // Helper for bindings
    func binding(for id: Int, dict: Binding<[Int: String]>, defaultVal: String) -> Binding<String> {
        return Binding(
            get: { dict.wrappedValue[id] ?? defaultVal },
            set: { dict.wrappedValue[id] = $0 }
        )
    }
    
    func loadCheckpoints() {
        api.isLoading = true
        api.errorMessage = nil
        Task {
            do {
                self.checkpoints = try await api.lookupCheckpoints(for: code)
                api.isLoading = false
            } catch {
                api.errorMessage = error.localizedDescription
                api.isLoading = false
            }
        }
    }
    
    func submit() {
        api.isLoading = true
        Task {
            let points = checkpoints.map { cp in
                ChecklistPointResult(
                    sjekkpunktId: cp.id,
                    oppgaveTekst: cp.text,
                    type: cp.type,
                    value: results[cp.id],
                    status: statuses[cp.id] ?? "OK",
                    comment: comments[cp.id]
                )
            }
            
            let reg = ChecklistRegistration(code: code, points: points, responsible: "iOS User")
            
            do {
                try await api.submitRegistration(registration: reg)
                api.isLoading = false
                // Handle success (e.g. dismiss or clear)
            } catch {
                api.errorMessage = error.localizedDescription
                api.isLoading = false
            }
        }
    }
}
