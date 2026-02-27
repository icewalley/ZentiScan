import SwiftUI

struct TaskRowView: View {
    @Binding var oppgave: Vedlikeholdsoppgave
    let jobId: Int
    @StateObject private var api = APIManager.shared

    @State private var showingDeviationModal = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(oppgave.tittel)
                        .font(.headline)

                    if let desc = oppgave.beskrivelse {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Sensor Info
                    if oppgave.sensorRef != nil {
                        HStack {
                            Image(systemName: "sensor")
                                .foregroundColor(.blue)
                            if oppgave.autoHentet, let verdi = oppgave.autoVerdi {
                                Text("Auto-hentet: \(String(format: "%.1f", verdi)) ✅")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Venter på sensordata...")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                Spacer()

                // Status Badge
                statusBadge(for: oppgave.status)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Actions
            if oppgave.status == .ikkeVurdert {
                HStack(spacing: 12) {
                    if oppgave.kreverBilde {
                        // Must report deviation or take picture
                        actionButton(
                            title: "Registrer (Krever Bilde)", icon: "camera", color: .blue
                        ) {
                            showingDeviationModal = true
                        }
                    } else {
                        actionButton(title: "OK", icon: "checkmark", color: .green) {
                            completeTask(status: .ok)
                        }

                        actionButton(
                            title: "Avvik", icon: "exclamationmark.triangle", color: .orange
                        ) {
                            showingDeviationModal = true
                        }

                        actionButton(title: "Hopp over", icon: "arrow.uturn.right", color: .gray) {
                            completeTask(status: .hoppetOver)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(oppgave.status == .avvik ? Color.red : Color.clear, lineWidth: 2)
        )
        .sheet(isPresented: $showingDeviationModal) {
            ReportDeviationView(oppgave: $oppgave, isPresented: $showingDeviationModal)
        }
    }

    private func completeTask(status: Vedlikeholdsoppgave.TaskStatus) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let updated = try await api.fullforOppgave(id: oppgave.id, status: status)
                DispatchQueue.main.async {
                    self.oppgave = updated
                }
            } catch {
                errorMessage = "Kunne ikke lagre: \(error.localizedDescription)"

                // MOCK BEHAVIOR
                DispatchQueue.main.async {
                    self.oppgave = Vedlikeholdsoppgave(
                        id: oppgave.id,
                        jobbId: oppgave.jobbId,
                        tittel: oppgave.tittel,
                        beskrivelse: oppgave.beskrivelse,
                        status: status,
                        kreverBilde: oppgave.kreverBilde,
                        sensorRef: oppgave.sensorRef,
                        autoVerdi: oppgave.autoVerdi,
                        autoHentet: oppgave.autoHentet,
                        maaleVerdi: oppgave.maaleVerdi
                    )
                }
            }
            isLoading = false
        }
    }

    private func actionButton(
        title: String, icon: String, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
                .foregroundColor(color)
                .cornerRadius(8)
            }
        }
        .disabled(isLoading)
    }

    @ViewBuilder
    private func statusBadge(for status: Vedlikeholdsoppgave.TaskStatus) -> some View {
        Group {
            switch status {
            case .ok:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .avvik:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            case .hoppetOver:
                Image(systemName: "nosign")
                    .foregroundColor(.gray)
            case .ikkeVurdert:
                EmptyView()
            }
        }
        .font(.title2)
    }
}
