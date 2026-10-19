import SwiftUI
import Combine

private enum AppScreen: Equatable {
    case setup, game, betweenTurns, finished
}

struct ContentView: View {
    @State private var screen: AppScreen = .setup
    @State private var players = [
        Player(name: "P1"), Player(name: "P2"),
        Player(name: "P3"), Player(name: "P4")
    ]
    @State private var nsfwMode = false
    @State private var turnIndex = 0
    @State private var conceptIndex = 0
    @State private var concepts: [String] = []
    @State private var revealed = false
    @State private var isRunning = false
    @State private var secondsRemaining = 150
    @State private var turnScores: [Int] = []
    @State private var conceptsThisTurn = 0
    @State private var showRules = false
    @State private var editingPlayer: UUID?
    @State private var draftName = ""
    @State private var showExitConfirm = false
    @State private var winningRoundPending = false
    @State private var winnerName = ""
    @State private var targetScore = 30
    @State private var showTargetPicker = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let background = Color(red: 0.055, green: 0.075, blue: 0.13)
    private let panel = Color(red: 0.105, green: 0.13, blue: 0.21)
    private let lime = Color(red: 0.67, green: 0.94, blue: 0.35)
    private let purple = Color(red: 0.65, green: 0.48, blue: 0.98)

    private var firstAlienIndex: Int { players.isEmpty ? 0 : turnIndex % players.count }
    private var secondAlienIndex: Int { players.isEmpty ? 0 : (turnIndex + 1) % players.count }
    private var firstAlien: Player? { players.indices.contains(firstAlienIndex) ? players[firstAlienIndex] : nil }
    private var secondAlien: Player? { players.indices.contains(secondAlienIndex) ? players[secondAlienIndex] : nil }
    private var totalTurnsPerCycle: Int { max(players.count * 2, 1) }
    private var turnLabel: String { "TURN \((turnIndex % totalTurnsPerCycle) + 1)/\(totalTurnsPerCycle)" }
    private var currentConcept: String {
        guard !concepts.isEmpty else { return "Tap to reveal your first concept" }
        return concepts[conceptIndex % concepts.count]
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            Group {
                switch screen {
                case .setup: setupView
                case .game: gameView
                case .betweenTurns: betweenTurnsView
                case .finished: finishedView
                }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(clock) { _ in
            guard screen == .game, isRunning else { return }
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            }
            if secondsRemaining == 0 {
                isRunning = false
                revealed = false
                screen = .betweenTurns
            }
        }
        .sheet(isPresented: $showRules) { rulesView }
        .alert("Rename player", isPresented: Binding(
            get: { editingPlayer != nil },
            set: { if !$0 { editingPlayer = nil } }
        )) {
            TextField("Player name", text: $draftName)
            Button("Save") {
                if let id = editingPlayer,
                   let index = players.firstIndex(where: { $0.id == id }) {
                    let cleaned = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty { players[index].name = String(cleaned.prefix(18)) }
                }
                editingPlayer = nil
            }
            Button("Cancel", role: .cancel) { editingPlayer = nil }
        }
        .confirmationDialog("Exit this game?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("Exit to setup", role: .destructive) { resetToSetup() }
            Button("Keep playing", role: .cancel) {}
        }
        .alert("End of game", isPresented: $showTargetPicker) {
            Button("Continue playing") { showTargetPicker = false }
            Button("Finish game", role: .destructive) {
                winnerName = players.sorted { $0.score > $1.score }.first?.name ?? "No one"
                screen = .finished
            }
        } message: {
            Text("A player has reached the suggested target score. You can continue playing or finish and view the scores.")
        }
    }

    private var setupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(eyebrow: "ALIENS, MEET EARTH", title: "WHAT ON EARTH?", subtitle: "Explain the impossible. Guess the ridiculous.")
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("PLAYERS", detail: "Drag rows to change seating order")
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.white.opacity(0.35))
                            ZStack {
                                Circle().fill(isAlien(index) ? lime : purple.opacity(0.22)).frame(width: 36, height: 36)
                                Image(systemName: isAlien(index) ? "alien" : "person.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(isAlien(index) ? background : .white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name).font(.headline)
                                Text(isAlien(index) ? "FIRST ALIENS" : "HUMAN / ALIEN")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(1.1)
                                    .foregroundStyle(isAlien(index) ? lime : .white.opacity(0.45))
                            }
                            Spacer()
                            Button {
                                draftName = player.name
                                editingPlayer = player.id
                            } label: {
                                Image(systemName: "pencil").foregroundStyle(.white.opacity(0.65)).padding(8)
                            }
                            .accessibilityLabel("Rename \(player.name)")
                            if players.count > 3 {
                                Button(role: .destructive) { players.removeAll { $0.id == player.id } } label: {
                                    Image(systemName: "minus.circle").foregroundStyle(.red.opacity(0.8)).padding(4)
                                }
                            }
                        }
                        .padding(12)
                        .background(isAlien(index) ? lime.opacity(0.10) : panel, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(isAlien(index) ? lime.opacity(0.45) : .white.opacity(0.05), lineWidth: 1))
                        .contextMenu {
                            if index > 0 {
                                Button("Move up") { players.swapAt(index, index - 1) }
                            }
                            if index < players.count - 1 {
                                Button("Move down") { players.swapAt(index, index + 1) }
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        Button { if players.count < 12 { players.append(Player(name: "P\(players.count + 1)")) } } label: {
                            Label("Add player", systemImage: "plus").font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(13)
                                .background(panel, in: RoundedRectangle(cornerRadius: 12))
                        }
                        Button { showRules = true } label: {
                            Label("How to play", systemImage: "questionmark.circle").font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(13)
                                .background(panel, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("DECK SETTINGS")
                    Toggle(isOn: $nsfwMode) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Cheeky mode").font(.headline)
                            Text("Adds mildly adult humour. Off by default.")
                                .font(.caption).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .tint(lime)
                    .padding(15)
                    .background(panel, in: RoundedRectangle(cornerRadius: 14))
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Suggested finish line").font(.subheadline.weight(.semibold))
                            Text("Score target (customisable)").font(.caption).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Picker("Target score", selection: $targetScore) {
                            Text("20").tag(20); Text("30").tag(30); Text("40").tag(40); Text("50").tag(50)
                        }
                        .pickerStyle(.menu)
                        .tint(lime)
                    }
                    .padding(15).background(panel, in: RoundedRectangle(cornerRadius: 14))
                    Text("The original board length was not specified, so the finish-line score is a customisable app setting.")
                        .font(.caption).foregroundStyle(.white.opacity(0.45))
                }
                Button(action: startGame) {
                    HStack {
                        Text("START GAME")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(background)
                    .padding(18)
                    .background(lime, in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(players.count < 3)
                Text("At least 3 players are needed. The first two players begin as Aliens.")
                    .font(.caption).foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
    }

    private var gameView: some View {
        VStack(spacing: 18) {
            HStack {
                Button { showExitConfirm = true } label: {
                    Image(systemName: "xmark").font(.headline).frame(width: 42, height: 42)
                        .background(panel, in: Circle())
                }
                Spacer()
                VStack(spacing: 3) {
                    Text(turnLabel).font(.system(size: 11, weight: .black, design: .rounded)).tracking(1.6).foregroundStyle(lime)
                    Text(timeString).font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                }
                Spacer()
                Button { isRunning.toggle() } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.headline).frame(width: 42, height: 42).background(panel, in: Circle())
                }
                .disabled(secondsRemaining == 0)
                .accessibilityLabel(isRunning ? "Pause timer" : "Resume timer")
            }

            HStack(spacing: 10) {
                alienPill(firstAlien, index: firstAlienIndex)
                alienPill(secondAlien, index: secondAlienIndex)
            }
            .padding(.horizontal, 2)

            HStack {
                Button { previousConcept() } label: {
                    Label("Previous", systemImage: "chevron.left").font(.caption.weight(.semibold))
                }
                Spacer()
                Text("\(conceptsThisTurn) GUESSED THIS TURN")
                    .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1)
                    .foregroundStyle(lime)
                Spacer()
                Button { nextConcept() } label: {
                    Label("Skip", systemImage: "chevron.right").font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 3)

            Spacer(minLength: 0)
            Button {
                revealed.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(colors: revealed ? [Color(red: 0.30, green: 0.22, blue: 0.50), Color(red: 0.15, green: 0.18, blue: 0.30)] : [Color(red: 0.17, green: 0.24, blue: 0.33), Color(red: 0.10, green: 0.14, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.15), lineWidth: 1)
                    VStack(spacing: 20) {
                        Image(systemName: revealed ? "sparkles" : "hand.tap.fill")
                            .font(.system(size: 34, weight: .medium)).foregroundStyle(lime)
                        if revealed {
                            Text(currentConcept)
                                .font(.system(size: 33, weight: .black, design: .rounded))
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.65)
                                .padding(.horizontal, 10)
                        } else {
                            Text("TAP TO REVEAL")
                                .font(.system(size: 18, weight: .black, design: .rounded)).tracking(2)
                            Text("Keep the concept hidden until the Humans are ready.")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
                        }
                        Text("EARTH CARD").font(.system(size: 10, weight: .black, design: .rounded)).tracking(2.5).foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(28)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 340)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(revealed ? currentConcept : "Reveal concept")

            if !isRunning && secondsRemaining > 0 {
                Button {
                    if !revealed { revealed = true }
                    isRunning = true
                } label: {
                    Label("START 2:30 TIMER", systemImage: "play.fill")
                        .font(.headline.weight(.black)).tracking(0.7)
                        .foregroundStyle(background).frame(maxWidth: .infinity).padding(16)
                        .background(lime, in: RoundedRectangle(cornerRadius: 14))
                }
            } else if isRunning {
                Text("Humans: translate together. Aliens: race to guess!")
                    .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 10) {
                Text("TAP THE ALIEN WHO GUESSED IT")
                    .font(.system(size: 10, weight: .black, design: .rounded)).tracking(1.5).foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 12) {
                    scoreButton(firstAlien, index: firstAlienIndex)
                    scoreButton(secondAlien, index: secondAlienIndex)
                }
            }
            .padding(14)
            .background(panel, in: RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
    }

    private var betweenTurnsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(eyebrow: "NICE WORK, EARTHLINGS", title: "TURN COMPLETE", subtitle: "The next Aliens are ready to take their seats.")
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("NEXT UP").font(.system(size: 11, weight: .black, design: .rounded)).tracking(1.8).foregroundStyle(lime)
                        Text("\(nextAlienName(0)) & \(nextAlienName(1))")
                            .font(.title2.weight(.black))
                    }
                    Spacer()
                    Image(systemName: "alien.fill").font(.system(size: 32)).foregroundStyle(lime)
                }
                .padding(18).background(panel, in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("SCOREBOARD")
                    ForEach(players.sorted { $0.score > $1.score }) { player in
                        HStack(spacing: 12) {
                            Circle().fill(isNextAlien(player) ? lime : purple.opacity(0.35)).frame(width: 34, height: 34)
                                .overlay(Text(String(player.name.prefix(1)).uppercased()).font(.headline.weight(.bold)).foregroundStyle(isNextAlien(player) ? background : .white))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name).font(.headline)
                                if isNextAlien(player) {
                                    Text("NEXT ALIEN").font(.system(size: 9, weight: .black, design: .rounded)).tracking(1).foregroundStyle(lime)
                                }
                            }
                            Spacer()
                            Text("\(player.score)").font(.title2.weight(.black).monospacedDigit()).foregroundStyle(lime)
                        }
                        .padding(13).background(panel, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
                Toggle(isOn: $nsfwMode) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Cheeky mode").font(.headline)
                        Text("Change the concept deck for the next turn.").font(.caption).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .tint(lime).padding(15).background(panel, in: RoundedRectangle(cornerRadius: 14))
                Button {
                    advanceTurn()
                } label: {
                    HStack {
                        Text("NEXT TURN")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline.weight(.black)).tracking(1)
                    .foregroundStyle(background).padding(18).background(lime, in: RoundedRectangle(cornerRadius: 16))
                }
                Button("Back to setup", systemImage: "arrow.uturn.backward") { resetToSetup() }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
    }

    private var finishedView: some View {
        VStack(spacing: 22) {
            Image(systemName: "trophy.fill").font(.system(size: 58)).foregroundStyle(lime)
            Text("EARTH CONQUERED").font(.system(size: 13, weight: .black, design: .rounded)).tracking(2).foregroundStyle(lime)
            Text(winnerName).font(.system(size: 38, weight: .black, design: .rounded)).multilineTextAlignment(.center)
            Text("wins this game!").font(.title3).foregroundStyle(.white.opacity(0.7))
            VStack(spacing: 10) {
                ForEach(players.sorted { $0.score > $1.score }) { player in
                    HStack {
                        Text(player.name).font(.headline)
                        Spacer()
                        Text("\(player.score) points").font(.headline.monospacedDigit()).foregroundStyle(lime)
                    }
                    .padding(14).background(panel, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Button { resetToSetup() } label: {
                Text("PLAY AGAIN").font(.headline.weight(.black)).tracking(1)
                    .foregroundStyle(background).frame(maxWidth: .infinity).padding(17)
                    .background(lime, in: RoundedRectangle(cornerRadius: 15))
            }
        }
        .padding(24).frame(maxWidth: 540).frame(maxWidth: .infinity)
    }

    private var rulesView: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ruleSection("THE MISSION", "One player describes a human concept while the two Aliens try to guess it. The Humans can use only words that follow the letters on their Translator Card, in order. An underscore is a wild letter.")
                        ruleSection("NO KEY WORDS", "Do not say a key word from the concept, any part of a key word, either half of a portmanteau, or words in an acronym. Do not use made-up or deliberately misspelled words, or body movements as clues.")
                        ruleSection("TAKE A TURN", "Tap the concept to reveal it. Start the 2:30 timer when ready. Humans translate together; the two Aliens race to guess. Tap the correct Alien's name to award a point and move to the next concept. Skip any concept that is too hard.")
                        ruleSection("ROTATION & WINNING", "After time runs out, the Alien roles move one seat clockwise. Scores are tracked for every player. The finish-line score in this prototype is a customisable convenience setting because the physical board's track length was not included in the supplied instructions.")
                        ruleSection("HOUSE RULE", "Close-enough guesses are judged by the Humans. Be fair, keep it moving, and have fun. Tinfoil hats are optional.")
                    }
                    .padding(22)
                }
            }
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showRules = false } } }
        }
        .presentationDetents([.large])
    }

    private var timeString: String {
        String(format: "%d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }

    private func header(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow).font(.system(size: 10, weight: .black, design: .rounded)).tracking(2.2).foregroundStyle(lime)
            Text(title).font(.system(size: 34, weight: .black, design: .rounded)).tracking(-0.7)
            Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private func sectionLabel(_ title: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 11, weight: .black, design: .rounded)).tracking(1.8).foregroundStyle(.white.opacity(0.55))
            Spacer()
            if let detail { Text(detail).font(.caption2).foregroundStyle(.white.opacity(0.35)) }
        }
    }

    private func isAlien(_ index: Int) -> Bool {
        !players.isEmpty && (index == firstAlienIndex || index == secondAlienIndex)
    }

    private func isNextAlien(_ player: Player) -> Bool {
        guard let index = players.firstIndex(where: { $0.id == player.id }) else { return false }
        let nextTurn = turnIndex + 1
        return index == nextTurn % players.count || index == (nextTurn + 1) % players.count
    }

    private func alienPill(_ player: Player?, index: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "alien.fill").foregroundStyle(lime)
            VStack(alignment: .leading, spacing: 2) {
                Text(player?.name ?? "Alien").font(.subheadline.weight(.bold))
                Text("GUESSER").font(.system(size: 9, weight: .black, design: .rounded)).tracking(1).foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).background(lime.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(lime.opacity(0.25), lineWidth: 1))
    }

    private func scoreButton(_ player: Player?, index: Int) -> some View {
        Button {
            guard isRunning, revealed, players.indices.contains(index) else { return }
            players[index].score += 1
            conceptsThisTurn += 1
            nextConcept()
            if players[index].score >= targetScore && !winningRoundPending {
                winningRoundPending = true
                // Let the current turn finish; the score target is a convenience for this digital prototype.
            }
        } label: {
            VStack(spacing: 7) {
                Image(systemName: "plus.circle.fill").font(.title2)
                Text(player?.name ?? "Alien").font(.headline.weight(.bold))
                Text("\(player?.score ?? 0) PTS").font(.system(size: 10, weight: .black, design: .rounded)).tracking(1)
            }
            .foregroundStyle(background)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(lime, in: RoundedRectangle(cornerRadius: 13))
        }
        .disabled(!isRunning || !revealed)
        .opacity((!isRunning || !revealed) ? 0.45 : 1)
    }

    private func startGame() {
        concepts = (nsfwMode ? ConceptDeck.familyFriendly + ConceptDeck.cheeky : ConceptDeck.familyFriendly).shuffled()
        turnIndex = 0
        players = players.map { Player(id: $0.id, name: $0.name, score: 0) }
        beginTurn()
        screen = .game
    }

    private func beginTurn() {
        secondsRemaining = 150
        isRunning = false
        revealed = false
        conceptsThisTurn = 0
        turnScores = Array(repeating: 0, count: players.count)
        if concepts.isEmpty {
            concepts = (nsfwMode ? ConceptDeck.familyFriendly + ConceptDeck.cheeky : ConceptDeck.familyFriendly).shuffled()
        }
    }

    private func advanceTurn() {
        turnIndex += 1
        if winningRoundPending && turnIndex % totalTurnsPerCycle == 0 {
            winningRoundPending = false
            winnerName = players.sorted { $0.score > $1.score }.first?.name ?? "No one"
            screen = .finished
            return
        }
        if turnIndex > 0 && turnIndex % totalTurnsPerCycle == 0 && players.contains(where: { $0.score >= targetScore }) {
            winnerName = players.sorted { $0.score > $1.score }.first?.name ?? "No one"
            screen = .finished
            return
        }
        concepts = (nsfwMode ? ConceptDeck.familyFriendly + ConceptDeck.cheeky : ConceptDeck.familyFriendly).shuffled()
        beginTurn()
        screen = .game
    }

    private func nextConcept() {
        guard !concepts.isEmpty else { return }
        conceptIndex = (conceptIndex + 1) % concepts.count
        revealed = true
    }

    private func previousConcept() {
        guard !concepts.isEmpty else { return }
        conceptIndex = (conceptIndex - 1 + concepts.count) % concepts.count
        revealed = true
    }

    private func nextAlienName(_ offset: Int) -> String {
        guard !players.isEmpty else { return "—" }
        return players[(turnIndex + 1 + offset) % players.count].name
    }

    private func resetToSetup() {
        isRunning = false
        screen = .setup
        turnIndex = 0
        conceptsThisTurn = 0
        winningRoundPending = false
        secondsRemaining = 150
        revealed = false
    }

    private func ruleSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(lime)
            Text(body).font(.body).foregroundStyle(.white.opacity(0.78)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ContentView()
}
