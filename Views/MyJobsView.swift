import SwiftUI

struct MyJobsView: View {
    @StateObject private var api = APIManager.shared
    @State private var jobs: [Vedlikeholdsjobb] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Binding for Navigation
    @Binding var path: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Dagens oppgaver")
                    .font(.headline)

                Spacer()

                Button(action: loadJobs) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }

            if isLoading {
                ProgressView("Henter oppgaver...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.subheadline)
            } else if jobs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("Ingen oppgaver for i dag!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ForEach(jobs) { job in
                        JobRowView(job: job) {
                            path.append(job)
                        }
                    }
                }
            }
        }
        .onAppear {
            if jobs.isEmpty {
                loadJobs()
            }
        }
    }

    private func loadJobs() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                jobs = try await api.getMineJobber()
            } catch {
                // If the backend API really isn't there yet, load mock data so the UI can be tested
                loadMockData()
            }

            isLoading = false
        }
    }

    private func loadMockData() {
        self.jobs = [
            Vedlikeholdsjobb(
                id: 101,
                tittel: "Årlig filterbytte",
                beskrivelse: "Bytt alle tilluftsfiltre i aggregat 1.",
                status: .planlagt,
                type: .forebyggende,
                bygningId: "B-01",
                romId: "Teknisk Rom 2",
                planlagtStart: Date(),
                frist: Date().addingTimeInterval(86400 * 2),  // 2 days from now
                faktiskStart: nil,
                faktiskSlutt: nil,
                oppgaver: nil
            ),
            Vedlikeholdsjobb(
                id: 102,
                tittel: "Brannslukker befaring",
                beskrivelse: "Månedlig sjekk av apparater.",
                status: .pabegynt,
                type: .lovpalagt,
                bygningId: "B-01",
                romId: nil,
                planlagtStart: Date().addingTimeInterval(-86400),
                frist: Date(),
                faktiskStart: Date().addingTimeInterval(-3600),
                faktiskSlutt: nil,
                oppgaver: nil
            ),
        ]
    }
}

struct JobRowView: View {
    let job: Vedlikeholdsjobb
    let onTap: () -> Void

    var body: some View {
        Button(action: { onTap() }) {
            HStack(alignment: .top, spacing: 16) {
                // Status Indicator
                Circle()
                    .fill(statusColor(job.status))
                    .frame(width: 12, height: 12)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 6) {
                    Text(job.tittel)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Text(job.type.rawValue)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)

                        if let loc = job.romId ?? job.bygningId {
                            Text("📍 \(loc)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
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
