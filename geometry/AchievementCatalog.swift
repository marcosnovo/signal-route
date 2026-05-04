import Foundation

// MARK: - Achievement Catalog

enum AchievementCatalog {

    private static let prefix = "com.marcosnovo.signalvoidgame.achievement"

    static let all: [Achievement] = [
        Achievement(
            id: "first_level",
            gcIdentifier: "\(prefix).first_level",
            titleEN: "First Circuit", titleES: "Primer Circuito", titleFR: "Premier Circuit",
            subtitleEN: "Complete your first level and light the signal.",
            subtitleES: "Completa tu primer nivel y enciende la se\u{00F1}al.",
            subtitleFR: "Termine ton premier niveau et allume le signal.",
            tier: .bronze, target: 1, metric: .levelsCompleted,
            accent: .sourceOrange, icon: "bolt.fill"
        ),
        Achievement(
            id: "complete_10",
            gcIdentifier: "\(prefix).complete_10",
            titleEN: "Signal Apprentice", titleES: "Aprendiz de Se\u{00F1}al", titleFR: "Apprenti du Signal",
            subtitleEN: "Complete 10 levels across the galaxy.",
            subtitleES: "Completa 10 niveles a trav\u{00E9}s de la galaxia.",
            subtitleFR: "Termine 10 niveaux \u{00E0} travers la galaxie.",
            tier: .bronze, target: 10, metric: .levelsCompleted,
            accent: .cyan, icon: "map.fill"
        ),
        Achievement(
            id: "complete_25",
            gcIdentifier: "\(prefix).complete_25",
            titleEN: "Route Engineer", titleES: "Ingeniero de Ruta", titleFR: "Ing\u{00E9}nieur de Route",
            subtitleEN: "Complete 25 levels across the galaxy.",
            subtitleES: "Completa 25 niveles a trav\u{00E9}s de la galaxia.",
            subtitleFR: "Termine 25 niveaux \u{00E0} travers la galaxie.",
            tier: .silver, target: 25, metric: .levelsCompleted,
            accent: .cyan, icon: "globe.americas.fill"
        ),
        Achievement(
            id: "complete_all",
            gcIdentifier: "\(prefix).complete_all",
            titleEN: "Void Architect", titleES: "Arquitecto del Vac\u{00ED}o", titleFR: "Architecte du Vide",
            subtitleEN: "Complete all 330 levels.",
            subtitleES: "Completa los 330 niveles.",
            subtitleFR: "Termine les 330 niveaux.",
            tier: .platinum, target: 330, metric: .levelsCompleted,
            accent: .gold, icon: "crown.fill"
        ),
        Achievement(
            id: "tier_easy_clear",
            gcIdentifier: "\(prefix).tier_easy_clear",
            titleEN: "Easy Mastered", titleES: "F\u{00E1}cil Dominado", titleFR: "Facile Ma\u{00EE}tris\u{00E9}",
            subtitleEN: "Clear all Easy levels.",
            subtitleES: "Supera todos los niveles F\u{00E1}cil.",
            subtitleFR: "Termine tous les niveaux Facile.",
            tier: .silver, target: 30, metric: .easyLevelsCleared,
            accent: .sage, icon: "leaf.fill"
        ),
        Achievement(
            id: "tier_medium_clear",
            gcIdentifier: "\(prefix).tier_medium_clear",
            titleEN: "Medium Mastered", titleES: "Medio Dominado", titleFR: "Moyen Ma\u{00EE}tris\u{00E9}",
            subtitleEN: "Clear all Medium levels.",
            subtitleES: "Supera todos los niveles Medio.",
            subtitleFR: "Termine tous les niveaux Moyen.",
            tier: .silver, target: 40, metric: .mediumLevelsCleared,
            accent: .amber, icon: "flame.fill"
        ),
        Achievement(
            id: "tier_hard_clear",
            gcIdentifier: "\(prefix).tier_hard_clear",
            titleEN: "Hard Mastered", titleES: "Dif\u{00ED}cil Dominado", titleFR: "Difficile Ma\u{00EE}tris\u{00E9}",
            subtitleEN: "Clear all Hard levels.",
            subtitleES: "Supera todos los niveles Dif\u{00ED}cil.",
            subtitleFR: "Termine tous les niveaux Difficile.",
            tier: .gold, target: 55, metric: .hardLevelsCleared,
            accent: .sourceOrange, icon: "bolt.trianglebadge.exclamationmark"
        ),
        Achievement(
            id: "tier_expert_clear",
            gcIdentifier: "\(prefix).tier_expert_clear",
            titleEN: "Expert Mastered", titleES: "Experto Dominado", titleFR: "Expert Ma\u{00EE}tris\u{00E9}",
            subtitleEN: "Clear all Expert levels.",
            subtitleES: "Supera todos los niveles Experto.",
            subtitleFR: "Termine tous les niveaux Expert.",
            tier: .platinum, target: 205, metric: .expertLevelsCleared,
            accent: .crimson, icon: "brain.head.profile.fill"
        ),
        Achievement(
            id: "perfect_run",
            gcIdentifier: "\(prefix).perfect_run",
            titleEN: "Optimal Route", titleES: "Ruta \u{00D3}ptima", titleFR: "Route Optimale",
            subtitleEN: "Finish a level with perfect efficiency.",
            subtitleES: "Termina un nivel con eficiencia perfecta.",
            subtitleFR: "Termine un niveau avec une efficacit\u{00E9} parfaite.",
            tier: .bronze, target: 1, metric: .perfectScores,
            accent: .sage, icon: "checkmark.seal.fill"
        ),
        Achievement(
            id: "perfect_x50",
            gcIdentifier: "\(prefix).perfect_x50",
            titleEN: "Perfectionist", titleES: "Perfeccionista", titleFR: "Perfectionniste",
            subtitleEN: "Get 50 perfect scores across any levels.",
            subtitleES: "Consigue 50 puntuaciones perfectas en cualquier nivel.",
            subtitleFR: "Obtiens 50 scores parfaits sur n'importe quels niveaux.",
            tier: .gold, target: 50, metric: .perfectScores,
            accent: .rose, icon: "scope"
        ),
        Achievement(
            id: "branch_master",
            gcIdentifier: "\(prefix).branch_master",
            titleEN: "Branching Mastered", titleES: "Ramificaci\u{00F3}n Dominada", titleFR: "Ramification Ma\u{00EE}tris\u{00E9}e",
            subtitleEN: "Clear all Branching levels.",
            subtitleES: "Supera todos los niveles de Ramificaci\u{00F3}n.",
            subtitleFR: "Termine tous les niveaux de Ramification.",
            tier: .silver, target: 42, metric: .branchingLevelsCleared,
            accent: .violet, icon: "arrow.triangle.branch"
        ),
        Achievement(
            id: "dense_master",
            gcIdentifier: "\(prefix).dense_master",
            titleEN: "Density Controlled", titleES: "Densidad Controlada", titleFR: "Densit\u{00E9} Contr\u{00F4}l\u{00E9}e",
            subtitleEN: "Clear all Dense levels.",
            subtitleES: "Supera todos los niveles Densos.",
            subtitleFR: "Termine tous les niveaux Denses.",
            tier: .silver, target: 76, metric: .denseLevelsCleared,
            accent: .amber, icon: "square.grid.3x3.fill"
        ),
        Achievement(
            id: "multi_node",
            gcIdentifier: "\(prefix).multi_node",
            titleEN: "Multi-Node", titleES: "Multinodo", titleFR: "Multi-Noeud",
            subtitleEN: "Clear all Multi-Node levels.",
            subtitleES: "Supera todos los niveles Multinodo.",
            subtitleFR: "Termine tous les niveaux Multi-Noeud.",
            tier: .silver, target: 130, metric: .multiNodeLevelsCleared,
            accent: .cyan, icon: "circle.hexagongrid.fill"
        ),
        Achievement(
            id: "no_retry",
            gcIdentifier: "\(prefix).no_retry",
            titleEN: "No Blink", titleES: "Sin Parpadeo", titleFR: "Sans Clignotement",
            subtitleEN: "Clear 50 levels on your first attempt.",
            subtitleES: "Supera 50 niveles en tu primer intento.",
            subtitleFR: "Termine 50 niveaux du premier coup.",
            tier: .gold, target: 50, metric: .firstAttemptClears,
            accent: .crimson, icon: "eye.fill"
        ),
    ]

    static func find(_ id: String) -> Achievement? {
        all.first { $0.id == id }
    }
}
