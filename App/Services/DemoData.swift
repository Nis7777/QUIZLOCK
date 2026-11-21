import Foundation

#if DEBUG
/// Screenshot / demo mode. Launch with `-demoData` (and optionally `-screen <name>`):
/// seeds a 12-day streak, sample stats, sample locked apps (Simulator mock) and a profile, then opens
/// `puzzles`, `word`, `chess`, `sudoku`, `stats`, `realityCheck` or `pickGames`. Debug builds only.
enum DemoData {
    static var arguments: [String] { ProcessInfo.processInfo.arguments }
    static var isEnabled: Bool { arguments.contains("-demoData") }
    static var screen: String? {
        guard let i = arguments.firstIndex(of: "-screen"), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    /// UI tests: `-uiTestFreshInstall` starts from an empty App Group (first launch), with iCloud sync off
    /// and the review prompt already "requested" so it can't block the test.
    static var isFreshInstallTest: Bool { arguments.contains("-uiTestFreshInstall") }

    /// Runs before AppModel reads anything from disk.
    static func seedIfRequested() {
        if isFreshInstallTest {
            let defaults = SharedStore.defaults
            for key in defaults.dictionaryRepresentation().keys { defaults.removeObject(forKey: key) }
            var settings = AppSettings()
            settings.ratingRequested = true
            SharedStore.save(settings, .settings)
            return
        }
        guard isEnabled else { return }
        let onboardingSteps: [String: OnboardingStep] = ["realityCheck": .realityCheck, "pickGames": .qPuzzles, "chat": .chat]
        let onboardingStep = screen.flatMap { onboardingSteps[$0] }
        let onboardingScreen = onboardingStep != nil

        var settings = AppSettings()
        settings.onboardingComplete = !onboardingScreen
        settings.onboardingStep = onboardingStep?.rawValue
        settings.showAllSetBanner = false
        settings.simulatorAuthorized = true
        settings.isPro = true
        settings.freeUnlocksUsed = 2
        settings.ratingRequested = true
        SharedStore.save(settings, .settings)

        var lock = LockState()
        lock.mockApps = ["TikTok", "Instagram", "YouTube"]
        lock.locksEnabled = true
        SharedStore.lockState = lock
        SharedStore.pendingUnlock = nil
        SharedStore.save(nil as UnlockSession?, .unlockSession)

        var profile = UserProfile()
        profile.name = "Alex"
        profile.source = .friend
        profile.scrollHours = .from4to6
        profile.wasters = [.shortVideos, .socialFeeds]
        profile.feelings = [.guilty, .foggy]
        profile.wants = [.reading, .sleep, .friends]
        profile.challenge = .balanced
        SharedStore.save(profile, .userProfile)

        var stats = Stats()
        let cal = Calendar.current
        let games = ["word", "chess", "math", "sudoku"]
        for offset in 0..<12 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            var d = DayStats()
            d.active = true
            d.solved[games[offset % 4]] = 1 + (offset * 7 % 4)
            d.solved[games[(offset + 1) % 4]] = offset % 3
            d.unlocksEarned = offset % 3
            d.unlocksSkipped = 1 + offset % 4
            d.minutesSaved = d.unlocksSkipped * 15
            d.dailyPuzzleSolved = offset > 0
            stats.days[StatsStore.key(for: day, calendar: cal)] = d
        }
        stats.celebratedMilestones = Stats.milestones
        StatsStore.save(stats)
    }

    /// Opens the requested screen once the app has bootstrapped.
    @MainActor
    static func route(_ model: AppModel) {
        guard isEnabled, let screen else { return }
        switch screen {
        case "puzzles":
            model.selectedTab = .puzzles
        case "stats":
            model.selectedTab = .settings
            model.showStats = true
        case "word":
            var round = WordRound(answer: "plant", difficulty: .easy)
            for guess in ["crane", "moist"] {
                for ch in guess { round.type(ch) }
                _ = round.submit(dictionary: model.rounds.wordDictionary)
            }
            for ch in "pla" { round.type(ch) }
            model.demoRounds[.word] = .word(round)
            model.practiceGame = .word
        case "chess":
            let puzzle = model.rounds.chessBank.firstEasyMateInOne ?? ChessPuzzleBank.fallback
            model.demoRounds[.chess] = .chess((try? ChessRound(puzzle: puzzle, difficulty: .easy)) ?? ChessRound.fallback(difficulty: .easy))
            model.practiceGame = .chess
        case "sudoku":
            var rng = SeededGenerator(seed: 2026)
            var round = SudokuRound(puzzle: SudokuGenerator.generate(difficulty: .easy, using: &rng), difficulty: .easy)
            let empties = (0..<81).filter { round.cells[$0] == 0 }
            for i in empties.prefix(9) { round.set(round.puzzle.solution[i], at: i) }
            model.demoRounds[.sudoku] = .sudoku(round)
            model.practiceGame = .sudoku
        default:
            break
        }
    }
}
#endif
