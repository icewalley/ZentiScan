import SwiftUI

struct ReportDeviationView: View {
    @Binding var oppgave: Vedlikeholdsoppgave
    @Binding var isPresented: Bool

    @StateObject private var api = APIManager.shared
    @State private var beskrivelse = ""
    @State private var alvorlighet = AvvikRegistrering.Alvorlighet.medium

    // Simulate photo
    @State private var byBypassingCamera = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Oppgave")) {
                    Text(oppgave.tittel)
                        .font(.headline)
                    if let desc = oppgave.beskrivelse {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Avviksdetaljer")) {
                    TextField("Beskriv problemet...", text: $beskrivelse, axis: .vertical)
                        .lineLimit(4...8)

                    Picker("Alvorlighet", selection: $alvorlighet) {
                        Text("Lav").tag(AvvikRegistrering.Alvorlighet.lav)
                        Text("Medium").tag(AvvikRegistrering.Alvorlighet.medium)
                        Text("Høy").tag(AvvikRegistrering.Alvorlighet.hoy)
                        Text("Kritisk").tag(AvvikRegistrering.Alvorlighet.kritisk)
                    }
                }

                Section(header: Text("Dokumentasjon")) {
                    HStack {
                        Image(
                            systemName: byBypassingCamera ? "checkmark.circle.fill" : "camera.fill"
                        )
                        .foregroundColor(byBypassingCamera ? .green : .blue)
                        Button(byBypassingCamera ? "Bilde vedlagt" : "Ta bilde") {
                            // Launch camera picker normally. Simulating here.
                            byBypassingCamera = true
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Registrer avvik")
            .navigationBarItems(
                leading: Button("Avbryt") { isPresented = false },
                trailing: Button("Lagre") { submitDeviation() }
                    .disabled(
                        beskrivelse.isEmpty || (oppgave.kreverBilde && !byBypassingCamera)
                            || isLoading)
            )
            .overlay {
                if isLoading {
                    ProgressView("Sender inn...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
    }

    private func submitDeviation() {
        isLoading = true
        errorMessage = nil

        let registrering = AvvikRegistrering(
            oppgaveId: oppgave.id,
            beskrivelse: beskrivelse,
            alvorlighet: alvorlighet,
            bildeBase64: byBypassingCamera ? "simulatedBase64String" : nil
        )

        Task {
            do {
                _ = try await api.registrerAvvik(registrering: registrering)
                // Mark task as avvik
                let updated = try await api.fullforOppgave(id: oppgave.id, status: .avvik)
                DispatchQueue.main.async {
                    self.oppgave = updated
                    self.isPresented = false
                }
            } catch {
                errorMessage = "Feil: \(error.localizedDescription)"

                // MOCK BEHAVIOR
                DispatchQueue.main.async {
                    self.oppgave = Vedlikeholdsoppgave(
                        id: oppgave.id,
                        jobbId: oppgave.jobbId,
                        tittel: oppgave.tittel,
                        beskrivelse: oppgave.beskrivelse,
                        status: .avvik,
                        kreverBilde: oppgave.kreverBilde,
                        sensorRef: oppgave.sensorRef,
                        autoVerdi: oppgave.autoVerdi,
                        autoHentet: oppgave.autoHentet,
                        maaleVerdi: oppgave.maaleVerdi
                    )
                    self.isPresented = false
                }
            }
            isLoading = false
        }
    }
}
