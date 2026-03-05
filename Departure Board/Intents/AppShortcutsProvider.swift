import AppIntents

struct DepartureBoardShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenBoardIntent(),
            phrases: [
                "Open \(.applicationName) board",
                "Open departures in \(.applicationName)"
            ],
            shortTitle: "Open Board",
            systemImageName: "train.side.front.car"
        )
        AppShortcut(
            intent: OpenFavouriteBoardIntent(),
            phrases: [
                "Open favourite board in \(.applicationName)",
                "Open my board in \(.applicationName)"
            ],
            shortTitle: "Open Favourite",
            systemImageName: "star.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .blue
}
