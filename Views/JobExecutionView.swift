import SwiftUI

struct JobExecutionView: View {
    @State var job: Vedlikeholdsjobb  // @State allows us to mutate it locally when updating status
    @StateObject private var api = APIManager.shared

    @State private var isLoadingAction = false
    @State private var errorMessage: String?

    // Timer properties
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Job Header
                headerCard

                // Timer & Primary Actions
                actionsSection

                // Error Display
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }

                // Checklists / Tasks
                if let oppgaver = job.oppgaver, !oppgaver.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sjekkliste (\(oppgaver.count) punkter)")
                            .font(.headline)
                            .padding(.horizontal)

                        // Render TaskRowViews dynamically
                        // We safely create a binding over the array
                        if let index = job.oppgaver?.startIndex {
                            ForEach(Array(oppgaver.enumerated()), id: \.element.id) {
                                (idx, oppgave) in
                                TaskRowView(
                                    oppgave: Binding(
                                        get: { job.oppgaver![idx] },
                                        set: { job.oppgaver![idx] = $0 }
                                    ),
                                    jobId: job.id
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                } else {
                    Text("Ingen spesifikke oppgaver er definert for denne jobben.")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
                }

            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(job.tittel)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupTimerIfRunning()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Components

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(job.type.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(job.type == .akutt ? Color.red : Color.blue)
                    .cornerRadius(8)

                Spacer()

                Text(job.status.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(statusColor(job.status))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(job.status).opacity(0.1))
                    .cornerRadius(8)
            }

            if let desc = job.beskrivelse {
                Text(desc)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(spacing: 20) {
                if let bygning = job.bygningId {
                    Label(bygning, systemImage: "building.2")
                        .font(.subheadline)
                }
                if let rom = job.romId {
                    Label(rom, systemImage: "door.left.hand.closed")
                        .font(.subheadline)
                }
                Spacer()
            }
            .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private var actionsSection: some View {
        VStack(spacing: 20) {

            // Timer Display
            if job.status == .pabegynt || job.faktiskStart != nil {
                HStack {
                    Image(systemName: "stopwatch")
                        .font(.title2)
                        .foregroundColor(job.status == .pabegynt ? .orange : .gray)

                    Text(timeString(from: elapsedSeconds))
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                }
            }

            if isLoadingAction {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                HStack(spacing: 16) {
                    // State Machine Logic for Buttons
                    if job.status == .planlagt || job.status == .avbrutt {
                        actionButton(title: "Start Jobb", icon: "play.fill", color: .green) {
                            handleAction(.start)
                        }
                    } else if job.status == .pabegynt {
                        actionButton(title: "Pause", icon: "pause.fill", color: .orange) {
                            handleAction(.pause)
                        }

                        actionButton(title: "Fullfør", icon: "checkmark.circle.fill", color: .blue)
                        {
                            handleAction(.fullfor)
                        }
                    } else if job.status == .utfort || job.status == .godkjent {
                        Text("Oppdraget er utført.")
                            .font(.headline)
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func actionButton(
        title: String, icon: String, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }

    // MARK: - Logic

    enum ActionType {
        case start, pause, gjenoppta, fullfor
    }

    private func handleAction(_ action: ActionType) {
        isLoadingAction = true
        errorMessage = nil

        Task {
            do {
                let updatedJob: Vedlikeholdsjobb

                switch action {
                case .start, .gjenoppta:
                    updatedJob = try await api.startJobb(id: job.id)
                case .pause:
                    updatedJob = try await api.pauseJobb(id: job.id)
                case .fullfor:
                    updatedJob = try await api.fullforJobb(id: job.id)
                }

                DispatchQueue.main.async {
                    self.job = updatedJob
                    self.setupTimerIfRunning()
                }

                if action == .fullfor {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                errorMessage = "Kunne ikke oppdatere jobben: \(error.localizedDescription)"

                // MOCK BEHAVIOR FOR UI TESTING IF API FAILS
                DispatchQueue.main.async {
                    mockStateTransition(action)
                }
            }
            isLoadingAction = false
        }
    }

    private func mockStateTransition(_ action: ActionType) {
        var start = job.faktiskStart
        var end = job.faktiskSlutt
        var newStatus = job.status

        switch action {
        case .start, .gjenoppta:
            start = start ?? Date()
            newStatus = .pabegynt
        case .pause:
            newStatus = .avbrutt
        case .fullfor:
            end = Date()
            newStatus = .utfort
        }

        job = Vedlikeholdsjobb(
            id: job.id,
            tittel: job.tittel,
            beskrivelse: job.beskrivelse,
            status: newStatus,
            type: job.type,
            bygningId: job.bygningId,
            romId: job.romId,
            planlagtStart: job.planlagtStart,
            frist: job.frist,
            faktiskStart: start,
            faktiskSlutt: end,
            oppgaver: job.oppgaver
        )
        setupTimerIfRunning()
    }

    private func setupTimerIfRunning() {
        timer?.invalidate()

        if job.status == .pabegynt, let start = job.faktiskStart {
            // Already running, calculate elapsed
            elapsedSeconds = Int(Date().timeIntervalSince(start))

            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                elapsedSeconds += 1
            }
        } else if let end = job.faktiskSlutt, let start = job.faktiskStart {
            // Finished, show total time
            elapsedSeconds = Int(end.timeIntervalSince(start))
        }
    }

    private func timeString(from totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = (totalSeconds % 3600) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func statusColor(_ status: Vedlikeholdsjobb.JobStatus) -> Color {
        switch status {
        case .planlagt: return .blue
        case .pabegynt: return .orange
        case .utfort, .godkjent: return .green
        case .avbrutt: return .red
        }
    }
}
