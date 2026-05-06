import Foundation

// MARK: - AppStrings
/// Localized UI strings for all supported languages (EN / ES / FR / JA).
/// Usage: `private var S: AppStrings { AppStrings(lang: settings.language) }`
struct AppStrings {
    let lang: AppLanguage

    private func t(_ en: String, _ es: String, _ fr: String, _ ja: String? = nil) -> String {
        switch lang {
        case .en: return en
        case .es: return es
        case .fr: return fr
        case .ja: return ja ?? en
        }
    }

    // MARK: - Navigation
    var close:  String { t("CLOSE",  "CERRAR",  "FERMER", "閉じる") }
    var back:   String { t("BACK",   "VOLVER",  "RETOUR", "戻る") }
    var home:   String { t("HOME",   "INICIO",  "ACCUEIL", "ホーム") }
    var skip:           String { t("SKIP",     "SALTAR",    "PASSER", "スキップ") }
    var continueAction: String { t("CONTINUE", "CONTINUAR", "CONTINUER", "続行") }
    var begin:          String { t("BEGIN",    "COMENZAR",  "COMMENCER", "開始") }

    // MARK: - Home — system bar
    var nodeActive: String { t("NODE ACTIVE",   "NODO ACTIVO",   "NŒUD ACTIF", "ノード稼働中") }
    var config:     String { t("CONFIG",        "CONFIG",        "CONFIG", "設定") }
    var rankings:   String { t("RANKINGS",      "CLASIFICACIÓN", "CLASSEMENT", "ランキング") }

    // MARK: - Home — title
    var restoreTheNetwork: String { t("RESTORE THE NETWORK", "RESTAURA LA RED", "RESTAURER LE RÉSEAU", "ネットワークを復旧せよ") }

    // MARK: - Home — mission section
    var nextMission:        String { t("NEXT MISSION",         "PRÓXIMA MISIÓN",          "PROCHAINE MISSION", "次のミッション") }
    var launch:             String { t("LAUNCH",               "LANZAR",                  "LANCER", "出撃") }
    var missionMap:         String { t("MISSION MAP",          "MAPA DE MISIONES",        "CARTE DES MISSIONS", "ミッションマップ") }
    var initializeTraining: String { t("INITIALIZE TRAINING",  "INICIAR ENTRENAMIENTO",   "INITIALISER L'ENTRAÎNEMENT", "トレーニング開始") }
    var systemCalibration:  String { t("SYSTEM CALIBRATION",   "CALIBRACIÓN DEL SISTEMA", "CALIBRATION DU SYSTÈME", "システム較正") }
    var trainingMission:    String { t("TRAINING MISSION",     "MISIÓN DE ENTRENAMIENTO", "MISSION D'ENTRAÎNEMENT", "訓練ミッション") }
    var required:           String { t("REQUIRED",             "REQUERIDO",               "REQUIS", "必須") }

    var allMissionsCleared: String { t("ALL MISSIONS CLEARED",      "TODAS LAS MISIONES COMPLETAS", "TOUTES LES MISSIONS ACCOMPLIES", "全ミッション完了") }
    func allMissionsClearedSub(count: Int) -> String {
        t("You've completed all \(count) missions.",
          "Has completado las \(count) misiones.",
          "Vous avez complété les \(count) missions.",
          "全\(count)ミッションを完了しました。")
    }

    // MARK: - Home — status strip
    var signalActive: String { t("SIGNAL  ·  ACTIVE",   "SEÑAL  ·  ACTIVA",   "SIGNAL  ·  ACTIF", "シグナル · 稼働中") }
    var missions:     String { t("MISSIONS",             "MISIONES",            "MISSIONS", "ミッション") }

    // MARK: - Astronaut progress card
    var astronautProfile:  String { t("MISSION CREDENTIAL",  "CREDENCIAL DE MISIÓN", "ACCRÉDITATION", "ミッション資格証") }
    var levelLabel:        String { t("LEVEL",              "NIVEL",                "NIVEAU", "レベル") }
    var destination:       String { t("DESTINATION",        "DESTINO",              "DESTINATION", "目的地") }
    var nextTarget:        String { t("NEXT TARGET",        "PRÓXIMO OBJETIVO",     "PROCHAINE CIBLE", "次の目標") }

    func progressToLevel(_ n: Int) -> String {
        t("PROGRESS TO LEVEL \(n)", "PROGRESO AL NIVEL \(n)", "PROGRESSION NIVEAU \(n)", "レベル\(n)への進行")
    }
    func toQualify(pct: Int) -> String {
        t("≥\(pct)% TO QUALIFY", "≥\(pct)% PARA CALIFICAR", "≥\(pct)% POUR QUALIFIER", "認定に≥\(pct)%必要")
    }
    var qualified:          String { t("QUALIFIED",           "CALIFICADAS",    "QUALIFIÉES", "認定済み") }
    var remaining:          String { t("REMAINING",           "PENDIENTES",     "RESTANTES", "残り") }
    var statusLabel:        String { t("STATUS",              "ESTADO",         "ÉTAT", "ステータス") }
    var ready:              String { t("READY",               "LISTO",          "PRÊT", "準備完了") }
    var avgEff:             String { t("AVG EFF",             "EFF. MEDIA",     "EFF. MOY.", "平均効率") }
    var tapToViewPlanetPass: String { t("TAP TO VIEW PLANET PASS", "TOCA PARA VER EL PASE", "TOUCHER POUR LE LAISSEZ-PASSER", "タップしてパスを表示") }
    var viewPass:            String { t("VIEW PASS",               "VER PASE",              "VOIR LE PASSE", "パスを表示") }

    // MARK: - Planet & region names (used in HomeView, LevelSelectView, pass cards)

    func planetName(_ name: String) -> String {
        switch name {
        case "EARTH ORBIT":   return t("EARTH ORBIT",   "ÓRBITA TERRESTRE",         "ORBITE TERRESTRE", "地球軌道")
        case "MOON":          return t("MOON",           "LUNA",                     "LUNE", "月")
        case "MARS":          return t("MARS",           "MARTE",                    "MARS", "火星")
        case "ASTEROID BELT": return t("ASTEROID BELT",  "CINTURÓN DE ASTEROIDES",   "CEINTURE D'ASTÉROÏDES", "小惑星帯")
        case "JUPITER":       return t("JUPITER",        "JÚPITER",                  "JUPITER", "木星")
        case "SATURN":        return t("SATURN",         "SATURNO",                  "SATURNE", "土星")
        case "URANUS":        return t("URANUS",         "URANO",                    "URANUS", "天王星")
        case "NEPTUNE":       return t("NEPTUNE",        "NEPTUNO",                  "NEPTUNE", "海王星")
        case "KUIPER BELT":   return t("KUIPER BELT",    "CINTURÓN DE KUIPER",       "CEINTURE DE KUIPER", "カイパーベルト")
        case "OORT CLOUD":    return t("OORT CLOUD",     "NUBE DE OORT",             "NUAGE D'OORT", "オールトの雲")
        default: return name
        }
    }

    func regionName(_ name: String) -> String {
        switch name {
        case "EARTH ORBIT":    return t("EARTH ORBIT",    "ÓRBITA TERRESTRE",         "ORBITE TERRESTRE", "地球軌道")
        case "LUNAR APPROACH": return t("LUNAR APPROACH", "APROXIMACIÓN LUNAR",       "APPROCHE LUNAIRE", "月面接近")
        case "MARS SECTOR":    return t("MARS SECTOR",    "SECTOR MARTE",             "SECTEUR MARS", "火星セクター")
        case "ASTEROID BELT":  return t("ASTEROID BELT",  "CINTURÓN DE ASTEROIDES",   "CEINTURE D'ASTÉROÏDES", "小惑星帯")
        case "JUPITER RELAY":  return t("JUPITER RELAY",  "RELÉ JÚPITER",             "RELAIS JUPITER", "木星リレー")
        case "SATURN RING":    return t("SATURN RING",    "ANILLOS DE SATURNO",       "ANNEAUX DE SATURNE", "土星リング")
        case "URANUS VOID":    return t("URANUS VOID",    "VACÍO DE URANO",           "VIDE D'URANUS", "天王星ボイド")
        case "NEPTUNE DEEP":   return t("NEPTUNE DEEP",   "NEPTUNO PROFUNDO",         "NEPTUNE PROFOND", "海王星ディープ")
        case "KUIPER BELT":    return t("KUIPER BELT",    "CINTURÓN DE KUIPER",       "CEINTURE DE KUIPER", "カイパーベルト")
        case "OORT CLOUD":     return t("OORT CLOUD",     "NUBE DE OORT",             "NUAGE D'OORT", "オールトの雲")
        default: return name
        }
    }

    func zoneBrief(_ brief: String) -> String {
        switch brief {
        case "TRAINING ZONE":       return t("TRAINING ZONE",       "ZONA DE ENTRENAMIENTO",     "ZONE D'ENTRAÎNEMENT", "訓練ゾーン")
        case "LUNAR APPROACH":      return t("LUNAR APPROACH",      "APROXIMACIÓN LUNAR",        "APPROCHE LUNAIRE", "月面接近")
        case "RED PLANET OPS":      return t("RED PLANET OPS",      "OPS PLANETA ROJO",          "OPS PLANÈTE ROUGE", "赤い惑星作戦")
        case "DEBRIS FIELD":        return t("DEBRIS FIELD",        "CAMPO DE ESCOMBROS",        "CHAMP DE DÉBRIS", "デブリフィールド")
        case "GAS GIANT RELAY":     return t("GAS GIANT RELAY",     "RELÉ DEL GIGANTE GASEOSO",  "RELAIS DU GÉANT GAZEUX", "ガス巨星リレー")
        case "GAS GIANT COMMS":     return t("GAS GIANT COMMS",     "COMMS GIGANTE GASEOSO",     "COMMS GÉANT GAZEUX", "ガス巨星通信")
        case "RING SYSTEM TRANSIT": return t("RING SYSTEM TRANSIT", "TRÁNSITO DE ANILLOS",       "TRANSIT DES ANNEAUX", "リング系通過")
        case "ICE GIANT SURVEY":    return t("ICE GIANT SURVEY",    "EXPLORACIÓN GIGANTE HELADO","EXPLORATION DU GÉANT GLACÉ", "氷巨星探査")
        case "DEEP SPACE COMMS":    return t("DEEP SPACE COMMS",    "COMMS ESPACIO PROFUNDO",    "COMMS ESPACE PROFOND", "深宇宙通信")
        case "PHASE 2 OPERATIONS":  return t("PHASE 2 OPERATIONS",  "OPERACIONES FASE 2",        "OPÉRATIONS PHASE 2", "フェーズ2作戦")
        case "FROZEN FRONTIER":     return t("FROZEN FRONTIER",     "FRONTERA HELADA",           "FRONTIÈRE GELÉE", "凍てつく辺境")
        case "DEEP VOID NETWORK":   return t("DEEP VOID NETWORK",   "RED DEL VACÍO PROFUNDO",    "RÉSEAU DU VIDE PROFOND", "深淵ネットワーク")
        default: return brief
        }
    }

    var missionEff: String { t("MISSION EFF", "EFF. MISIÓN", "EFF. MISSION", "ミッション効率") }

    // MARK: - Planet ticket
    var planetPass:           String { t("PLANET PASS",                  "PASE PLANETARIO",               "LAISSEZ-PASSER", "惑星パス") }
    var trainingClearance:    String { t("TRAINING CLEARANCE",            "AUTORIZACIÓN DE ENTRENAMIENTO", "AUTORISATION D'ENTRAÎNEMENT", "訓練許可証") }
    var shareProgress:        String { t("SHARE PROGRESS",               "COMPARTIR PROGRESO",            "PARTAGER LA PROGRESSION", "進捗を共有") }
    /// Share sheet body text — personalised with the player's current level.
    func shareProgressText(level: Int) -> String {
        t(
            "I reached level \(level) in SIGNAL VOID 🚀\nCan you go further?",
            "He alcanzado el nivel \(level) en SIGNAL VOID 🚀\n¿Puedes llegar más lejos?",
            "J'ai atteint le niveau \(level) dans SIGNAL VOID 🚀\nPeux-tu aller plus loin ?",
            "SIGNAL VOIDでレベル\(level)に到達 🚀\nもっと先に行ける？"
        )
    }
    // Ticket renderer labels (CGContext-rendered image)
    var accessAuthorized:     String { t("ACCESS AUTHORIZED",             "ACCESO AUTORIZADO",             "ACCÈS AUTORISÉ", "アクセス許可") }
    var inTraining:           String { t("IN TRAINING",                   "EN ENTRENAMIENTO",              "EN FORMATION", "訓練中") }
    var missionEfficiency:    String { t("MISSION EFFICIENCY",            "EFICIENCIA DE MISIÓN",          "EFFICACITÉ DE MISSION", "ミッション効率") }
    var rankLabel:            String { t("RANK",                          "RANGO",                         "RANG", "ランク") }
    var clearedStatus:        String { t("CLEARED",                       "COMPLETADO",                    "VALIDÉ", "完了") }
    var inProgressStatus:     String { t("IN PROGRESS",                   "EN PROGRESO",                   "EN COURS", "進行中") }
    var sectorTransitPass:    String { t("SECTOR TRANSIT PASS",           "PASE DE TRÁNSITO",              "LAISSEZ-PASSER SECTEUR", "セクター通過パス") }
    var authorizedBearer:     String { t("AUTHORIZED BEARER",             "PORTADOR AUTORIZADO",           "PORTEUR AUTORISÉ", "認定所持者") }

    // MARK: - Onboarding tutorial
    var tutorialTitle:        String { t("MISSION BRIEFING",              "INFORME DE MISIÓN",             "BRIEFING DE MISSION", "ミッションブリーフィング") }
    var tutorialBody:         String { t("Connect the signal source to the target by tapping tiles to rotate them.",
                                         "Conecta la fuente de señal al objetivo tocando los bloques para rotarlos.",
                                         "Connectez la source du signal à la cible en touchant les tuiles pour les tourner.",
                                         "タイルをタップして回転させ、シグナル源をターゲットに接続してください。") }
    var tutorialSignalSource: String { t("SIGNAL SOURCE",                 "FUENTE DE SEÑAL",               "SOURCE DU SIGNAL", "シグナル源") }
    var tutorialTargetRelay:  String { t("TARGET RELAY",                  "RELÉ OBJETIVO",                 "RELAIS CIBLE", "ターゲットリレー") }
    var tutorialBeginMission: String { t("BEGIN MISSION",                 "INICIAR MISIÓN",                "COMMENCER LA MISSION", "ミッション開始") }
    var tutorialTapHint:      String { t("TAP TILES TO ROTATE",           "TOCA BLOQUES PARA ROTAR",       "TOUCHEZ POUR TOURNER", "タップして回転") }

    func difficultyFullLabel(_ tier: DifficultyTier) -> String {
        switch tier {
        case .easy:   return t("EASY",   "FÁCIL",   "FACILE", "イージー")
        case .medium: return t("MEDIUM", "MEDIO",   "MOYEN", "ミディアム")
        case .hard:   return t("HARD",   "DIFÍCIL", "DIFFICILE", "ハード")
        case .expert: return t("EXPERT", "EXPERTO", "EXPERT", "エキスパート")
        }
    }

    var renderingPass:        String { t("RENDERING PASS…",              "GENERANDO PASE…",               "GÉNÉRATION DU LAISSEZ-PASSER…", "パス生成中…") }
    var preparingPass:        String { t("PREPARING PLANET PASS",        "PREPARANDO PASE PLANETARIO",    "PRÉPARATION DU LAISSEZ-PASSER", "惑星パス準備中") }
    var generatingCredential: String { t("GENERATING MISSION CREDENTIAL","GENERANDO CREDENCIAL DE MISIÓN","GÉNÉRATION DES ACCRÉDITATIONS", "資格証を生成中") }

    // MARK: - Mission card labels
    var dailyMission:    String { t("DAILY MISSION",  "MISIÓN DIARIA",  "MISSION QUOTIDIENNE", "デイリーミッション") }
    var complete:        String { t("COMPLETE",       "COMPLETA",       "TERMINÉE", "完了") }
    var failed:          String { t("FAILED",         "FALLIDA",        "ÉCHOUÉE", "失敗") }
    var gridLabel:       String { t("GRID",           "CUADRÍCULA",     "GRILLE", "グリッド") }
    var objectiveLabel:  String { t("OBJECTIVE",      "OBJETIVO",       "OBJECTIF", "目標") }
    var targetsLabel:    String { t("TARGETS",        "OBJETIVOS",      "CIBLES", "ターゲット") }
    var signalLabel:     String { t("SIGNAL",         "SEÑAL",          "SIGNAL", "シグナル") }
    var activeValue:     String { t("ACTIVE",         "ACTIVA",         "ACTIF", "稼働中") }
    var readyValue:      String { t("READY",          "LISTA",          "PRÊTE", "準備完了") }
    var movesLabel:      String { t("MOVES",          "MOVIMIENTOS",    "MOUVEMENTS", "手数") }
    var efficiencyLabel: String { t("EFFICIENCY",     "EFICIENCIA",     "EFFICACITÉ", "効率") }
    var movesUsedLabel:  String { t("MOVES USED",     "MOVS. USADOS",   "MOUVS. UTILISÉS", "使用手数") }

    // MARK: - Mission map
    var missionMapTitle: String { t("MISSION MAP",     "MAPA DE MISIONES", "CARTE DES MISSIONS", "ミッションマップ") }
    func missionsComplete(done: Int, total: Int) -> String {
        t("\(done) / \(total) COMPLETE", "\(done) / \(total) COMPLETADAS", "\(done) / \(total) TERMINÉES", "\(done) / \(total) 完了")
    }
    var activeSector:   String { t("ACTIVE SECTOR",  "SECTOR ACTIVO",    "SECTEUR ACTIF", "アクティブセクター") }
    var sectorComplete: String { t("SECTOR COMPLETE", "SECTOR COMPLETADO", "SECTEUR TERMINÉ", "セクター完了") }
    var lockedLabel:    String { t("LOCKED",           "BLOQUEADO",        "VERROUILLÉ", "ロック中") }
    var missionsLabel:  String { t("MISSIONS",         "MISIONES",         "MISSIONS", "ミッション") }
    func levelRequired(_ n: Int) -> String { t("LVL \(n)", "NIV \(n)", "NIV \(n)", "LV \(n)") }
    var next:           String { t("NEXT",             "SGTE",             "SUIV.", "次") }
    var viewMissions:   String { t("VIEW MISSIONS",    "VER MISIONES",     "VOIR LES MISSIONS", "ミッション表示") }
    var hideMissions:   String { t("HIDE MISSIONS",    "OCULTAR MISIONES", "MASQUER LES MISSIONS", "ミッション非表示") }
    var completePreviousSectors: String { t("COMPLETE PREVIOUS SECTORS", "COMPLETA SECTORES ANTERIORES", "TERMINER LES SECTEURS PRÉCÉDENTS", "前のセクターを完了してください") }
    func unlockAtLevel(_ n: Int) -> String { t("UNLOCK AT LEVEL \(n)", "DESBLOQUEAR EN NIVEL \(n)", "DÉBLOQUER AU NIVEAU \(n)", "レベル\(n)で解放") }
    var avgEfficiency:  String { t("AVG EFFICIENCY",   "EFIC. MEDIA",      "EFF. MOYENNE", "平均効率") }
    var missionsCount:  String { t("MISSIONS",         "MISIONES",         "MISSIONS", "ミッション") }

    // MARK: - Settings
    var systemConfig:        String { t("SYSTEM CONFIG",     "CONFIG. DEL SISTEMA", "CONFIG. DU SYSTÈME", "システム設定") }
    var audio:               String { t("AUDIO",             "AUDIO",               "AUDIO", "オーディオ") }
    var soundFX:             String { t("SOUND FX",          "EFECTOS DE SONIDO",   "EFFETS SONORES", "効果音") }
    var soundFXSub:          String { t("Game sound effects", "Efectos de juego",   "Effets du jeu", "ゲーム効果音") }
    var ambientMusic:        String { t("AMBIENT MUSIC",     "MÚSICA AMBIENTAL",    "MUSIQUE D'AMBIANCE", "環境音楽") }
    var ambientMusicSub:     String { t("Background drone",  "Dron de fondo",       "Drone d'ambiance", "バックグラウンドドローン") }
    var interfaceSection:    String { t("INTERFACE",         "INTERFAZ",            "INTERFACE", "インターフェース") }
    var hapticFeedback:      String { t("HAPTIC FEEDBACK",   "FEEDBACK HÁPTICO",    "RETOUR HAPTIQUE", "触覚フィードバック") }
    var hapticFeedbackSub:   String { t("Vibration on actions", "Vibración en acciones", "Vibration sur les actions", "操作時の振動") }
    var reducedMotion:       String { t("REDUCED MOTION",    "MOVIMIENTO REDUCIDO", "MOUVEMENT RÉDUIT", "視差効果を減らす") }
    var reducedMotionSub:    String { t("Simplify animations", "Simplificar animaciones", "Simplifier les animations", "アニメーションを簡略化") }
    var language:            String { t("LANGUAGE",          "IDIOMA",              "LANGUE", "言語") }

    // MARK: - Game HUD
    var movesRemaining:    String { t("MOVES REMAINING",  "MOVIMIENTOS RESTANTES", "MOUVEMENTS RESTANTS", "残り手数") }
    var usedLabel:         String { t("USED",             "USADOS",                "UTILISÉS", "使用済み") }
    var parLabel:          String { t("PAR",              "PAR",                   "PAR", "PAR") }
    var timeRemaining:     String { t("TIME REMAINING",   "TIEMPO RESTANTE",       "TEMPS RESTANT", "残り時間") }
    var elapsed:           String { t("ELAPSED",          "TRANSCURRIDO",          "ÉCOULÉ", "経過") }
    var objectiveHUD:      String { t("OBJECTIVE",        "OBJETIVO",              "OBJECTIF", "目標") }
    var gridCoverage:      String { t("GRID COVERAGE",    "COBERTURA DE RED",      "COUVERTURE DU RÉSEAU", "グリッドカバー率") }
    var extraNodes:        String { t("EXTRA NODES",      "NODOS EXTRA",           "NŒUDS EN EXCÈS", "余分なノード") }
    var coverageMinHint:   String { t("· MIN 50% COVERAGE", "· COBERTURA MÍN 50%", "· COUVERTURE MIN 50%", "· 最低50%カバー率") }
    var reduceNetwork:     String { t("· REDUCE NETWORK", "· REDUCE LA RED",       "· RÉDUIRE LE RÉSEAU", "· ネットワークを縮小") }
    var targetsOnline:     String { t("TARGETS ONLINE",   "OBJETIVOS ACTIVOS",     "CIBLES ACTIVES", "稼働ターゲット") }
    var activeNodes:       String { t("ACTIVE NODES",     "NODOS ACTIVOS",         "NŒUDS ACTIFS", "稼働ノード") }
    var coverage:          String { t("COVERAGE",         "COBERTURA",             "COUVERTURE", "カバー率") }
    var waste:             String { t("WASTE",            "DERROCHE",              "GASPILLAGE", "無駄") }
    var network:           String { t("NETWORK",          "RED",                   "RÉSEAU", "ネットワーク") }
    var online:            String { t("ONLINE",           "EN LÍNEA",              "EN LIGNE", "オンライン") }
    var offline:           String { t("OFFLINE",          "DESCONECTADA",          "HORS LIGNE", "オフライン") }

    // Hint text
    var rotateTilesToRouteSignal: String {
        t("ROTATE TILES TO ROUTE THE SIGNAL",
          "ROTA LOS BLOQUES PARA DIRIGIR LA SEÑAL",
          "ROTEZ LES BLOCS POUR ACHEMINER LE SIGNAL",
          "タイルを回転させてシグナルを送れ")
    }
    var tapAnyTileToRotate: String {
        t("TAP ANY TILE TO ROTATE IT",
          "TOCA UN BLOQUE PARA ROTARLO",
          "TOUCHEZ UN BLOC POUR LE FAIRE PIVOTER",
          "タイルをタップして回転")
    }
    var tapTileToRotate: String {
        t("TAP TILE TO ROTATE",
          "TOCA UN BLOQUE PARA ROTAR",
          "TOUCHER UN BLOC POUR PIVOTER",
          "タップして回転")
    }

    // MARK: - Objective text (Game HUD banner)
    func objectiveText(type: LevelObjectiveType, targets: Int) -> String {
        switch type {
        case .normal:
            return targets > 1
                ? t("ACTIVATE \(targets) TARGETS", "ACTIVAR \(targets) OBJETIVOS", "ACTIVER \(targets) CIBLES", "\(targets)個のターゲットを起動")
                : t("BRIDGE THE VOID",              "CRUZAR EL VACÍO",              "COMBLER LE VIDE", "ボイドを繋げ")
        case .maxCoverage:
            return t("MAXIMIZE ACTIVE GRID",  "MAXIMIZAR RED ACTIVA",  "MAXIMISER LE RÉSEAU ACTIF", "グリッド稼働率を最大化")
        case .energySaving:
            return t("SAVE ENERGY",           "AHORRAR ENERGÍA",       "ÉCONOMISER L'ÉNERGIE", "エネルギーを節約")
        }
    }

    // MARK: - LevelObjectiveType HUD label
    func hudLabel(_ type: LevelObjectiveType) -> String {
        switch type {
        case .normal:       return t("ACTIVATE TARGETS",     "ACTIVAR OBJETIVOS",    "ACTIVER LES CIBLES", "ターゲット起動")
        case .maxCoverage:  return t("MAXIMIZE ACTIVE GRID", "MAXIMIZAR RED ACTIVA", "MAXIMISER LE RÉSEAU", "グリッド最大化")
        case .energySaving: return t("SAVE ENERGY",          "AHORRAR ENERGÍA",      "ÉCONOMISER L'ÉNERGIE", "省エネルギー")
        }
    }

    // MARK: - Mission overlay (win / lose)
    var statusSuccess:  String { t("STATUS: SUCCESS",    "ESTADO: ÉXITO",      "ÉTAT: SUCCÈS", "ステータス: 成功") }
    var statusFailure:  String { t("STATUS: FAILURE",    "ESTADO: FALLO",      "ÉTAT: ÉCHEC", "ステータス: 失敗") }
    var networkRestored: String { t("NETWORK RESTORED",  "RED RESTAURADA",     "RÉSEAU RESTAURÉ", "ネットワーク復旧") }
    var signalLost:     String { t("SIGNAL LOST",        "SEÑAL PERDIDA",      "SIGNAL PERDU", "シグナル消失") }
    var score:          String { t("SCORE",              "PUNTUACIÓN",         "SCORE", "スコア") }
    var movesOverlay:   String { t("MOVES",              "MOVIMIENTOS",        "MOUVEMENTS", "手数") }
    var remainingOverlay: String { t("REMAINING",        "RESTANTES",          "RESTANTS", "残り") }
    var retryLevel:     String { t("RETRY LEVEL",        "REINTENTAR NIVEL",   "RÉESSAYER LE NIVEAU", "レベルをリトライ") }
    var tryAgain:       String { t("TRY AGAIN",          "INTENTAR DE NUEVO",  "RÉESSAYER", "もう一度") }
    var shareResult:    String { t("SHARE RESULT",       "COMPARTIR RESULTADO","PARTAGER LE RÉSULTAT", "結果を共有") }
    var returnToBase:   String { t("RETURN TO BASE",     "VOLVER A LA BASE",   "RETOUR À LA BASE", "基地に帰還") }
    var efficiencyBar:  String { t("EFFICIENCY",         "EFICIENCIA",         "EFFICACITÉ", "効率") }

    // MARK: - Sector complete overlay
    /// "COMPLETE" label shown below the planet name on the sector-complete interstitial.
    var zoneComplete: String { t("COMPLETE", "COMPLETADO", "TERMINÉ", "完了") }
    /// "[PLANET] ACCESS GRANTED" — label shown above the pass card.
    func zoneAccessGranted(_ name: String) -> String {
        t("\(name) ACCESS GRANTED", "\(name): ACCESO CONCEDIDO", "\(name): ACCÈS ACCORDÉ", "\(name) アクセス許可")
    }

    // MARK: - Intro win overlay
    var signalRouted:              String { t("VOID BRIDGED",                "VACÍO CRUZADO",                  "VIDE COMBLÉ", "ボイド接続完了") }
    var networkOnline:             String { t("NETWORK ONLINE",              "RED EN LÍNEA",                   "RÉSEAU EN LIGNE", "ネットワーク稼働") }
    var systemCalibrationComplete: String { t("SYSTEM CALIBRATION COMPLETE", "CALIBRACIÓN DEL SISTEMA COMPLETA","CALIBRATION DU SYSTÈME TERMINÉE", "システム較正完了") }
    var clearedForDeployment:      String { t("CLEARED FOR DEPLOYMENT",      "AUTORIZADO PARA EL DESPLIEGUE",  "AUTORISÉ POUR LE DÉPLOIEMENT", "配備許可") }
    var accessGranted:             String { t("ACCESS GRANTED",              "ACCESO CONCEDIDO",               "ACCÈS ACCORDÉ", "アクセス許可") }

    // MARK: - Intro fail overlay
    var routingFailed:             String { t("ROUTING FAILED",              "ENRUTAMIENTO FALLIDO",           "ROUTAGE ÉCHOUÉ", "ルーティング失敗") }
    var networkDisconnected:       String { t("NETWORK DISCONNECTED",        "RED DESCONECTADA",               "RÉSEAU DÉCONNECTÉ", "ネットワーク切断") }
    var introFailInstruction:      String { t("ROTATE THE TILES TO CONNECT THE SOURCE NODE TO THE TARGET NODE", "ROTA LAS PIEZAS PARA CONECTAR EL NODO ORIGEN CON EL NODO DESTINO", "FAITES PIVOTER LES TUILES POUR CONNECTER LE NŒUD SOURCE AU NŒUD CIBLE", "タイルを回転させてソースノードをターゲットノードに接続してください") }
    var retryMission:              String { t("RETRY MISSION",               "REINTENTAR MISIÓN",              "RÉESSAYER LA MISSION", "ミッションをリトライ") }
    var signalEstablished:         String { t("SIGNAL ESTABLISHED",          "SEÑAL ESTABLECIDA",              "SIGNAL ÉTABLI", "シグナル確立") }
    func missionProgress(_ n: Int, _ total: Int) -> String {
        t("\(n) / \(total) MISSIONS", "\(n) / \(total) MISIONES", "\(n) / \(total) MISSIONS", "\(n) / \(total) ミッション")
    }

    // MARK: - Mechanic unlock
    var newMechanicUnlocked: String { t("NEW MECHANIC UNLOCKED",    "NUEVA MECÁNICA DESBLOQUEADA", "NOUVELLE MÉCANIQUE DÉBLOQUÉE", "新メカニクス解放") }
    var understood:          String { t("UNDERSTOOD",               "ENTENDIDO",                   "COMPRIS", "了解") }

    func mechanicTitle(_ type: MechanicType) -> String {
        switch type {
        case .rotationCap:      return t("ROTATION LIMIT",    "LÍMITE DE ROTACIÓN",    "LIMITE DE ROTATION", "回転制限")
        case .overloaded:       return t("OVERLOADED RELAY",  "RELÉ SOBRECARGADO",     "RELAIS SURCHARGÉ", "過負荷リレー")
        case .timeLimit:        return t("TIME PRESSURE",     "PRESIÓN TEMPORAL",      "PRESSION TEMPORELLE", "時間制限")
        case .autoDrift:        return t("NODE DRIFT",        "DERIVA DE NODO",        "DÉRIVE DE NŒUD", "ノードドリフト")
        case .oneWayRelay:      return t("ONE-WAY RELAY",     "RELÉ UNIDIRECCIONAL",   "RELAIS UNIDIRECTIONNEL", "一方通行リレー")
        case .fragileTile:      return t("FRAGILE RELAY",     "RELÉ FRÁGIL",           "RELAIS FRAGILE", "脆弱リレー")
        case .chargeGate:       return t("CHARGE GATE",       "COMPUERTA DE CARGA",    "PORTE DE CHARGE", "チャージゲート")
        case .interferenceZone: return t("INTERFERENCE",      "INTERFERENCIA",         "INTERFÉRENCE", "干渉")
        }
    }

    func mechanicMessage(_ type: MechanicType) -> String {
        switch type {
        case .rotationCap:
            return t(
                "Your training is progressing fast. Some components are now unstable and can only be rotated a limited number of times. Plan every move carefully.",
                "Tu entrenamiento avanza rápido. Algunos componentes son inestables y solo pueden rotarse un número limitado de veces. Planifica cada movimiento.",
                "Votre entraînement progresse vite. Certains composants sont instables et ne peuvent être pivotés qu'un nombre limité de fois. Planifiez chaque mouvement.",
                "訓練は順調に進んでいます。一部のコンポーネントが不安定で、回転回数に制限があります。一手一手を慎重に計画してください。"
            )
        case .overloaded:
            return t(
                "High-resistance nodes have been detected in the network. Some relays require two commands to rotate — arm first, then execute.",
                "Se han detectado nodos de alta resistencia en la red. Algunos relés requieren dos comandos para rotar: primero armar, luego ejecutar.",
                "Des nœuds à haute résistance ont été détectés dans le réseau. Certains relais nécessitent deux commandes pour pivoter — armer d'abord, puis exécuter.",
                "ネットワーク内に高抵抗ノードが検出されました。一部のリレーは回転に2段階のコマンドが必要です — まずアーム、次に実行。"
            )
        case .timeLimit:
            return t(
                "You've shown remarkable routing skills. We believe time won't be a problem for you anymore. From now on, some missions must be completed under time pressure.",
                "Has demostrado habilidades de enrutamiento notables. Creemos que el tiempo no será un problema para ti. A partir de ahora, algunas misiones deben completarse contra el reloj.",
                "Vous avez démontré des compétences d'acheminement remarquables. Désormais, certaines missions doivent être accomplies sous pression temporelle.",
                "優れたルーティング能力を発揮しました。もう時間は問題にならないでしょう。今後、一部のミッションは制限時間内に完了する必要があります。"
            )
        case .autoDrift:
            return t(
                "Advanced systems are now entering the simulation. Some nodes won't hold their orientation for long. Stabilize the route before they shift again.",
                "Sistemas avanzados entran ahora en la simulación. Algunos nodos no mantendrán su orientación por mucho tiempo. Estabiliza la ruta antes de que se desplacen.",
                "Des systèmes avancés entrent dans la simulation. Certains nœuds ne garderont pas leur orientation longtemps. Stabilisez la route avant qu'ils ne basculent à nouveau.",
                "高度なシステムがシミュレーションに導入されます。一部のノードは向きを長く保てません。再びずれる前にルートを安定させてください。"
            )
        case .oneWayRelay:
            return t(
                "Advanced routing protocols unlocked. Some relays now only accept signal from specific directions. Read the grid carefully.",
                "Protocolos de enrutamiento avanzados desbloqueados. Algunos relés solo aceptan señal desde direcciones específicas. Lee la cuadrícula con cuidado.",
                "Protocoles d'acheminement avancés débloqués. Certains relais n'acceptent le signal que depuis des directions spécifiques. Lisez attentivement la grille.",
                "高度なルーティングプロトコルが解放されました。一部のリレーは特定の方向からのみシグナルを受信します。グリッドをよく読んでください。"
            )
        case .fragileTile:
            return t(
                "Network components are degrading. Some relays can only handle limited exposure to the energy field before burning out permanently. Route efficiently before they fail.",
                "Los componentes de la red se están degradando. Algunos relés solo soportan una exposición limitada al campo de energía antes de quemarse. Enruta con eficiencia antes de que fallen.",
                "Les composants du réseau se dégradent. Certains relais ne supportent qu'une exposition limitée au champ d'énergie avant de griller. Achemninez efficacement avant qu'ils ne lâchent.",
                "ネットワーク部品が劣化しています。一部のリレーはエネルギー場への露出に限界があり、永久に焼損します。故障する前に効率的にルーティングしてください。"
            )
        case .chargeGate:
            return t(
                "Locked subsystems detected. Some relays require multiple charge cycles before they conduct. Keep the signal flowing until the gate opens.",
                "Se detectaron subsistemas bloqueados. Algunos relés requieren varios ciclos de carga antes de conducir. Mantén el flujo de señal hasta que la compuerta se abra.",
                "Sous-systèmes verrouillés détectés. Certains relais nécessitent plusieurs cycles de charge avant de conduire. Maintenez le signal jusqu'à l'ouverture de la porte.",
                "ロックされたサブシステムを検出。一部のリレーは導通前に複数の充電サイクルが必要です。ゲートが開くまでシグナルを流し続けてください。"
            )
        case .interferenceZone:
            return t(
                "Electromagnetic interference detected in the grid. Some sectors are compromised — visual readings may be distorted. Trust the signal, not your eyes.",
                "Se ha detectado interferencia electromagnética en la cuadrícula. Algunos sectores están comprometidos — las lecturas visuales pueden estar distorsionadas. Confía en la señal, no en tus ojos.",
                "Interférence électromagnétique détectée dans la grille. Certains secteurs sont compromis — les lectures visuelles peuvent être déformées. Fiez-vous au signal, pas à vos yeux.",
                "グリッド内に電磁干渉を検出。一部のセクターが影響を受けています — 視覚情報が歪んでいる可能性があります。目ではなくシグナルを信じてください。"
            )
        }
    }

    // MARK: - Mission clearance (onboarding bridge screen)
    var missionControlEncryptedLink: String { t("MISSION CONTROL  ·  ENCRYPTED LINK",   "CONTROL DE MISIÓN  ·  ENLACE CIFRADO",    "CONTRÔLE MISSION  ·  LIEN CHIFFRÉ", "ミッションコントロール · 暗号化リンク") }
    var clearanceGranted:            String { t("CLEARANCE GRANTED",                    "AUTORIZACIÓN CONCEDIDA",                   "AUTORISATION ACCORDÉE", "認可") }
    var missionReadyTitle:           String { t("MISSION READY",                        "MISIÓN LISTA",                             "MISSION PRÊTE", "ミッション準備完了") }
    var clearedForFirstMission:      String { t("You are cleared for your first mission.", "Estás autorizado para tu primera misión.", "Tu es autorisé pour ta première mission.", "最初のミッションへの出撃が許可されました。") }
    var mission1EarthOrbit:          String { t("MISSION 1  ·  EARTH ORBIT",            "MISIÓN 1  ·  ÓRBITA TERRESTRE",            "MISSION 1  ·  ORBITE TERRESTRE", "ミッション1 · 地球軌道") }
    var launchMission:               String { t("LAUNCH MISSION",                       "LANZAR MISIÓN",                            "LANCER LA MISSION", "ミッション出撃") }

    // MARK: - Story beat UI labels
    var incomingTransmission: String { t("INCOMING TRANSMISSION", "TRANSMISIÓN ENTRANTE", "TRANSMISSION ENTRANTE", "受信中の通信") }
    var acknowledge:          String { t("ACKNOWLEDGE",           "RECONOCER",            "RECONNAÎTRE", "確認") }
    var understoodCTA:        String { t("UNDERSTOOD",            "ENTENDIDO",            "COMPRIS", "了解") }

    /// Returns the localized version of a story beat footer hint.
    /// The English text is used as the key; falls back to the original string for unknown hints.
    func storyFooterHint(_ hint: String) -> String {
        switch hint {
        case "EARTH ORBIT SECTOR ACTIVE":     return t(hint, "SECTOR ÓRBITA TERRESTRE ACTIVO",          "SECTEUR ORBITE TERRESTRE ACTIF", "地球軌道セクター稼働中")
        case "MISSION 1 LOADED":              return t(hint, "MISIÓN 1 CARGADA",                         "MISSION 1 CHARGÉE", "ミッション1ロード完了")
        case "NEXT WINDOW: 24H":             return t(hint, "PRÓXIMA VENTANA: 24H",                     "PROCHAINE FENÊTRE: 24H", "次のウィンドウ: 24時間後")
        case "LUNAR APPROACH UNLOCKED":       return t(hint, "LLEGADA LUNAR DESBLOQUEADA",               "APPROCHE LUNAIRE DÉBLOQUÉE", "月面接近 解放")
        case "MARS SECTOR UNLOCKED":          return t(hint, "SECTOR MARTE DESBLOQUEADO",                "SECTEUR MARS DÉBLOQUÉ", "火星セクター 解放")
        case "ASTEROID BELT ROUTE OPEN":      return t(hint, "RUTA DEL CINTURÓN ABIERTA",               "ROUTE DE LA CEINTURE OUVERTE", "小惑星帯ルート 開通")
        case "JUPITER RELAY APPROACH OPEN":   return t(hint, "ACCESO AL RELÉ JÚPITER ABIERTO",          "ACCÈS AU RELAIS JUPITER OUVERT", "木星リレー接近 開通")
        case "SATURN RING SECTOR OPEN":       return t(hint, "SECTOR ANILLOS DE SATURNO ABIERTO",       "SECTEUR ANNEAUX DE SATURNE OUVERT", "土星リングセクター 開通")
        case "URANUS VOID SECTOR OPEN":       return t(hint, "SECTOR VACÍO DE URANO ABIERTO",           "SECTEUR VIDE D'URANUS OUVERT", "天王星ボイドセクター 開通")
        case "NEPTUNE DEEP SECTOR OPEN":      return t(hint, "SECTOR PROFUNDO DE NEPTUNO ABIERTO",      "SECTEUR PROFOND DE NEPTUNE OUVERT", "海王星ディープセクター 開通")
        case "KUIPER BELT SECTOR OPEN":       return t(hint, "SECTOR CINTURÓN DE KUIPER ABIERTO",       "SECTEUR CEINTURE DE KUIPER OUVERT", "カイパーベルトセクター 開通")
        case "OORT CLOUD SECTOR OPEN":        return t(hint, "SECTOR NUBE DE OORT ABIERTO",             "SECTEUR NUAGE D'OORT OUVERT", "オールトの雲セクター 開通")
        case "FULL NETWORK OPERATIONAL":      return t(hint, "RED COMPLETA OPERATIVA",                   "RÉSEAU COMPLET OPÉRATIONNEL", "全ネットワーク稼働")
        case "RANK: PILOT":                   return t(hint, "RANGO: PILOTO",                             "RANG: PILOTE", "ランク: パイロット")
        case "RANK: NAVIGATOR":               return t(hint, "RANGO: NAVEGANTE",                          "RANG: NAVIGATEUR", "ランク: ナビゲーター")
        case "RANK: COMMANDER":               return t(hint, "RANGO: COMANDANTE",                         "RANG: COMMANDANT", "ランク: コマンダー")
        case "ROTATION LIMIT ACTIVE":         return t(hint, "LÍMITE DE ROTACIÓN ACTIVO",                "LIMITE DE ROTATION ACTIVE", "回転制限 有効")
        case "TWO-TAP PROTOCOL ACTIVE":       return t(hint, "PROTOCOLO DE DOS TOQUES ACTIVO",           "PROTOCOLE À DEUX TOUCHES ACTIF", "2タッププロトコル 有効")
        case "AUTO-DRIFT ACTIVE":             return t(hint, "DERIVA AUTOMÁTICA ACTIVA",                 "DÉRIVE AUTOMATIQUE ACTIVE", "オートドリフト 有効")
        case "ONE-WAY RELAY ACTIVE":          return t(hint, "RELÉ UNIDIRECCIONAL ACTIVO",               "RELAIS UNIDIRECTIONNEL ACTIF", "一方通行リレー 有効")
        case "FRAGILE RELAY ACTIVE":          return t(hint, "RELÉ FRÁGIL ACTIVO",                       "RELAIS FRAGILE ACTIF", "脆弱リレー 有効")
        case "CHARGE GATE ACTIVE":            return t(hint, "COMPUERTA DE CARGA ACTIVA",                "PORTE DE CHARGE ACTIVE", "チャージゲート 有効")
        case "INTERFERENCE ZONE ACTIVE":      return t(hint, "ZONA DE INTERFERENCIA ACTIVA",             "ZONE D'INTERFÉRENCE ACTIVE", "干渉ゾーン 有効")
        case "TIME LIMIT ACTIVE":             return t(hint, "LÍMITE DE TIEMPO ACTIVO",                  "LIMITE DE TEMPS ACTIVE", "制限時間 有効")
        case "ASTEROID BELT UNLOCKED":        return t(hint, "CINTURÓN DE ASTEROIDES DESBLOQUEADO",     "CEINTURE D'ASTÉROÏDES DÉBLOQUÉE", "小惑星帯 解放")
        case "JUPITER RELAY UNLOCKED":        return t(hint, "RELÉ JÚPITER DESBLOQUEADO",                "RELAIS JUPITER DÉBLOQUÉ", "木星リレー 解放")
        case "SATURN RING SECTOR UNLOCKED":   return t(hint, "SECTOR ANILLOS DE SATURNO DESBLOQUEADO",  "SECTEUR ANNEAUX DE SATURNE DÉBLOQUÉ", "土星リングセクター 解放")
        case "URANUS VOID UNLOCKED":          return t(hint, "VACÍO DE URANO DESBLOQUEADO",              "VIDE D'URANUS DÉBLOQUÉ", "天王星ボイド 解放")
        case "NEPTUNE DEEP UNLOCKED":         return t(hint, "PROFUNDO NEPTUNO DESBLOQUEADO",            "NEPTUNE PROFOND DÉBLOQUÉ", "海王星ディープ 解放")
        case "KUIPER BELT UNLOCKED":          return t(hint, "CINTURÓN DE KUIPER DESBLOQUEADO",          "CEINTURE DE KUIPER DÉBLOQUÉE", "カイパーベルト 解放")
        case "OORT CLOUD UNLOCKED":           return t(hint, "NUBE DE OORT DESBLOQUEADA",               "NUAGE D'OORT DÉBLOQUÉ", "オールトの雲 解放")
        case "SECTOR 2 — LUNAR APPROACH":    return t(hint, "SECTOR 2 — LLEGADA LUNAR",                 "SECTEUR 2 — APPROCHE LUNAIRE", "セクター2 — 月面接近")
        case "SECTOR 3 — MARS SECTOR":       return t(hint, "SECTOR 3 — SECTOR MARTE",                  "SECTEUR 3 — SECTEUR MARS", "セクター3 — 火星セクター")
        case "SECTOR 4 — ASTEROID BELT":     return t(hint, "SECTOR 4 — CINTURÓN DE ASTEROIDES",       "SECTEUR 4 — CEINTURE D'ASTÉROÏDES", "セクター4 — 小惑星帯")
        case "SECTOR 5 — JUPITER RELAY":     return t(hint, "SECTOR 5 — RELÉ JÚPITER",                 "SECTEUR 5 — RELAIS JUPITER", "セクター5 — 木星リレー")
        case "SECTOR 6 — SATURN RING":       return t(hint, "SECTOR 6 — ANILLOS DE SATURNO",           "SECTEUR 6 — ANNEAUX DE SATURNE", "セクター6 — 土星リング")
        case "SECTOR 7 — URANUS VOID":       return t(hint, "SECTOR 7 — VACÍO DE URANO",               "SECTEUR 7 — VIDE D'URANUS", "セクター7 — 天王星ボイド")
        case "SECTOR 8 — NEPTUNE DEEP":      return t(hint, "SECTOR 8 — NEPTUNO PROFUNDO",             "SECTEUR 8 — NEPTUNE PROFOND", "セクター8 — 海王星ディープ")
        case "SECTOR 9 — KUIPER BELT":       return t(hint, "SECTOR 9 — CINTURÓN DE KUIPER",           "SECTEUR 9 — CEINTURE DE KUIPER", "セクター9 — カイパーベルト")
        case "SECTOR 10 — OORT CLOUD":       return t(hint, "SECTOR 10 — NUBE DE OORT",                "SECTEUR 10 — NUAGE D'OORT", "セクター10 — オールトの雲")
        default: return hint
        }
    }

    func storyTriggerLabel(_ trigger: StoryTrigger) -> String {
        switch trigger {
        case .firstLaunch:          return t("MISSION BRIEF",       "INFORME DE MISIÓN",       "BRIEFING MISSION", "ミッションブリーフ")
        case .firstMissionReady:    return t("MISSION READY",       "MISIÓN LISTA",            "MISSION PRÊTE", "ミッション準備完了")
        case .firstMissionComplete: return t("MISSION REPORT",      "INFORME DE MISIÓN",       "RAPPORT DE MISSION", "ミッションレポート")
        case .onboardingComplete:   return t("GATE ACTIVE",         "COMPUERTA ACTIVA",        "PORTE ACTIVE", "ゲート稼働")
        case .sectorComplete:       return t("SECTOR CLEARED",      "SECTOR DESPEJADO",        "SECTEUR DÉGAGÉ", "セクター完了")
        case .passUnlocked:         return t("PASS ISSUED",         "PASE EMITIDO",            "LAISSEZ-PASSER ÉMIS", "パス発行")
        case .rankUp:               return t("RANK UPDATE",         "ACTUALIZACIÓN DE RANGO",  "MISE À JOUR DU RANG", "ランク更新")
        case .mechanicUnlocked:     return t("FIELD ALERT",         "ALERTA DE CAMPO",         "ALERTE TERRAIN", "フィールドアラート")
        case .enteringNewSector:    return t("NEW SECTOR",          "NUEVO SECTOR",            "NOUVEAU SECTEUR", "新セクター")
        }
    }

    // MARK: - Upgrade / monetization CTAs
    var unlimitedAccess:          String { t("UNLIMITED ACCESS",          "ACCESO ILIMITADO",          "ACCÈS ILLIMITÉ", "無制限アクセス") }
    var continueWithoutLimits:    String { t("CONTINUE WITHOUT LIMITS",   "CONTINÚA SIN LÍMITES",      "CONTINUER SANS LIMITES", "制限なしで続行") }
    var upgradeLabel:             String { t("UPGRADE",                   "MEJORAR",                   "AMÉLIORER", "アップグレード") }
    var unlockUnlimitedAccess:    String { t("UNLOCK UNLIMITED ACCESS",   "DESBLOQUEAR ACCESO",        "DÉBLOQUER L'ACCÈS", "無制限アクセスを解放") }
    var playWithoutDailyLimit:    String { t("Play without daily limit",  "Juega sin límite diario",   "Joue sans limite quotidienne", "デイリー制限なしでプレイ") }
    var gateLocked:               String { t("ACCESS LOCKED",             "ACCESO BLOQUEADO",          "ACCÈS VERROUILLÉ", "アクセスロック") }
    var availableIn:              String { t("Available in",              "Disponible en",             "Disponible dans", "利用可能まで") }
    var cooldownActive:           String { t("NEXT WINDOW OPENS IN",      "PRÓXIMA VENTANA EN",        "PROCHAINE FENÊTRE DANS", "次のウィンドウまで") }
    var upgradeForInstantAccess:  String { t("Upgrade for instant access","Mejora para acceso inmediato","Améliorer pour accès immédiat", "アップグレードで即時アクセス") }
    var keepPlayingWithoutWaiting: String { t("Keep playing without waiting", "Sigue jugando sin esperas", "Continuez sans attendre", "待たずにプレイを続ける") }
    var leaderboard:               String { t("RANKING",   "CLASIFICACIÓN", "CLASSEMENT", "ランキング") }
    var connectForLeaderboard:     String { t("CONNECT",   "CONECTAR",  "CONNECTER", "接続") }
    func backIn(_ time: String) -> String { t("Back in \(time)", "Vuelve a jugar en \(time)", "De retour dans \(time)", "\(time)後に復帰") }
    func dailyPlaysLabel(used: Int, limit: Int) -> String {
        t("\(used)/\(limit) missions used today",
          "\(used)/\(limit) misiones usadas hoy",
          "\(used)/\(limit) missions utilisées aujourd'hui",
          "本日 \(used)/\(limit) ミッション使用済み")
    }

    // MARK: - Paywall
    var paywallTitle:           String { t("Unlock Signal Void",               "Desbloquea Signal Void",                "Débloquez Signal Void", "Signal Voidを解放") }
    var paywallSubtitle:        String { t("Play all 330 levels without limits","Juega sin límites los 330 niveles",     "Jouez aux 330 niveaux sans limite", "330レベルすべてを制限なしでプレイ") }
    var paywallFeatureLevels:   String { t("Full access to all 330 levels",    "Acceso completo a los 330 niveles",     "Accès complet aux 330 niveaux", "全330レベルへのフルアクセス") }
    var paywallFeatureNoLimit:  String { t("No daily mission limit",           "Sin límite diario de misiones",         "Aucune limite quotidienne de missions", "デイリーミッション制限なし") }
    var paywallFeatureOneTime:  String { t("One-time payment, forever",        "Pago único, para siempre",              "Paiement unique, pour toujours", "買い切り、永久に") }
    var paywallFeatureFamily:   String { t("Family Sharing supported",         "Compatible con Compartir en familia",   "Compatible avec le Partage familial", "ファミリー共有対応") }
    var paywallFeatureDaily:   String { t("Exclusive Daily Challenge mode",    "Modo Desafío Diario exclusivo",         "Mode Défi Quotidien exclusif", "限定デイリーチャレンジモード") }

    // MARK: Daily Challenge
    var dailyChallenge:          String { t("DAILY CHALLENGE",                 "DESAFÍO DIARIO",                        "DÉFI QUOTIDIEN", "デイリーチャレンジ") }
    var dailyChallengeSubtitle:  String { t("ONE ATTEMPT. ONE CHANCE.",        "UN INTENTO. UNA OPORTUNIDAD.",          "UN ESSAI. UNE CHANCE.", "1回の挑戦。1度のチャンス。") }
    var dailyChallengeCompleted: String { t("COMPLETED",                       "COMPLETADO",                            "TERMINÉ", "完了") }
    var dailyChallengePlayed:   String { t("PLAYED",                          "JUGADO",                                "JOUÉ", "プレイ済み") }
    var dailyChallengeNextIn:   String { t("NEW CHALLENGE IN",                "NUEVO DESAFÍO EN",                      "NOUVEAU DÉFI DANS", "次のチャレンジまで") }
    func nextIn(_ time: String) -> String { t("NEXT IN \(time)",              "SIGUIENTE EN \(time)",                  "PROCHAIN DANS \(time)", "次まで \(time)") }
    var dailyScore:              String { t("DAILY SCORE",                   "PUNTUACIÓN DIARIA",                     "SCORE QUOTIDIEN", "デイリースコア") }
    var dailyCumulative:         String { t("DAILY CUMULATIVE",              "ACUMULADO DIARIO",                      "CUMUL QUOTIDIEN", "デイリー累計") }
    var dailyChallengeReady:     String { t("ARE YOU READY?",                "¿ESTÁS PREPARADO?",                     "ÊTES-VOUS PRÊT ?", "準備はいいですか？") }
    var dailyChallengeWarning:   String { t("This challenge can only be played once per day. You cannot pause or exit once started.",
                                            "Este desafío solo se puede jugar una vez al día. No puedes pausar ni salir una vez iniciado.",
                                            "Ce défi ne peut être joué qu'une fois par jour. Vous ne pouvez ni mettre en pause ni quitter une fois lancé.",
                                            "このチャレンジは1日1回のみプレイ可能です。開始後は一時停止や退出はできません。") }
    var dailyChallengePlay:      String { t("PLAY",                          "JUGAR",                                 "JOUER", "プレイ") }
    var dailyChallengeNotReady:  String { t("NOT READY YET",                 "AÚN NO ESTOY PREPARADO",               "PAS ENCORE PRÊT", "まだ準備ができていない") }
    var today:                   String { t("TODAY",                          "HOY",                                   "AUJOURD'HUI", "本日") }
    var dailyRankGlobal:         String { t("DAILY RANKING",                  "CLASIFICACIÓN DIARIA",                  "CLASSEMENT QUOTIDIEN", "デイリーランキング") }
    var leaderboardPickerTitle:  String { t("RANKINGS",                       "CLASIFICACIONES",                       "CLASSEMENTS", "ランキング") }
    var leaderboardGlobal:       String { t("GLOBAL SCORE",                   "PUNTUACIÓN GLOBAL",                     "SCORE GLOBAL", "グローバルスコア") }
    var leaderboardDaily:        String { t("TODAY'S CHALLENGE",              "DESAFÍO DE HOY",                        "DÉFI DU JOUR", "今日のチャレンジ") }
    var leaderboardWeekly:       String { t("WEEKLY ACCUMULATED",             "ACUMULADO SEMANAL",                     "CUMUL HEBDOMADAIRE", "週間累計") }
    var leaderboardByDifficulty: String { t("BY DIFFICULTY",                  "POR DIFICULTAD",                        "PAR DIFFICULTÉ", "難易度別") }
    var leaderboardLoading:      String { t("LOADING…",                       "CARGANDO…",                             "CHARGEMENT…", "読み込み中…") }
    var leaderboardEmpty:        String { t("No rankings yet",                "Sin clasificaciones aún",               "Pas encore de classement", "まだランキングがありません") }
    var leaderboardYourRank:     String { t("YOUR RANK",                      "TU POSICIÓN",                           "VOTRE RANG", "あなたの順位") }
    func leaderboardOfTotal(_ total: Int) -> String { t("of \(total) players", "de \(total) jugadores", "sur \(total) joueurs", "\(total)人中") }
    var challengeFriend:         String { t("CHALLENGE A FRIEND",             "RETAR A UN AMIGO",                      "DÉFIER UN AMI", "フレンドに挑戦") }
    var challengeSubtitle:       String { t("Beat my score!",                 "¡Supera mi puntuación!",                "Bats mon score !", "私のスコアを超えろ！") }
    var noRankYet:               String { t("—",                              "—",                                     "—", "—") }
    var achievements:            String { t("ACHIEVEMENTS",                   "LOGROS",                                "SUCCÈS", "実績") }
    var achievementCompleted:    String { t("COMPLETED",                      "COMPLETADO",                            "TERMINÉ", "達成") }
    var achievementLocked:       String { t("LOCKED",                         "BLOQUEADO",                             "VERROUILLÉ", "未解放") }
    var achievementReplayable:   String { t("REPEATABLE",                     "REPETIBLE",                             "REJOUABLE", "繰り返し可") }
    func achievementPoints(_ n: Int) -> String { t("\(n) PTS", "\(n) PTS", "\(n) PTS", "\(n) PTS") }
    func achievementRarity(_ pct: Int) -> String { t("Earned by \(pct)% of players", "Obtenido por el \(pct)% de jugadores", "Obtenu par \(pct)% des joueurs", "プレイヤーの\(pct)%が獲得") }
    var achievementProgress:     String { t("PROGRESS",                       "PROGRESO",                              "PROGRÈS", "進捗") }
    var achievementDate:         String { t("DATE",                           "FECHA",                                 "DATE", "日付") }
    var achievementStats:        String { t("STATS",                          "ESTADÍSTICAS",                          "STATISTIQUES", "統計") }
    var achievementComingSoon:   String { t("Coming soon",                    "Próximamente",                          "Bientôt disponible", "近日公開") }
    func achievementCount(_ done: Int, _ total: Int) -> String { t("\(done) of \(total) unlocked", "\(done) de \(total) desbloqueados", "\(done) sur \(total) débloqués", "\(total)中\(done)解放済み") }
    var achievementChallenge:    String { t("CHALLENGE A FRIEND",             "RETAR A UN AMIGO",                      "DÉFIER UN AMI", "フレンドに挑戦") }
    var challengesTab:           String { t("CHALLENGES",                     "RETOS",                                 "DÉFIS", "チャレンジ") }
    var challengeStart:          String { t("START CHALLENGE",                "INICIAR RETO",                          "LANCER LE DÉFI", "チャレンジ開始") }
    var challengeActive:         String { t("ACTIVE",                         "ACTIVO",                                "ACTIF", "アクティブ") }
    var challengeRepeatable:     String { t("REPEATABLE",                     "REPETIBLE",                             "REJOUABLE", "繰り返し可") }
    var challengeNone:           String { t("No challenges available",        "No hay retos disponibles",              "Aucun défi disponible", "利用可能なチャレンジなし") }
    var challengeSelectTitle:    String { t("SELECT CHALLENGE",               "SELECCIONAR RETO",                      "SÉLECTIONNER DÉFI", "チャレンジを選択") }
    var leaderboardGlobalShort:  String { t("GLOBAL",                        "GLOBAL",                                "GLOBAL", "グローバル") }
    var leaderboardDailyShort:   String { t("CHALLENGE",                     "DESAFÍO",                               "DÉFI", "チャレンジ") }
    var leaderboardAccumShort:   String { t("ACCUMULATED",                   "ACUMULADO",                             "CUMULÉ", "累計") }
    var dailyChallengeContext:   String { t("DAILY CHALLENGE \u{00B7} TODAY", "DESAFÍO DIARIO \u{00B7} HOY",          "DÉFI QUOTIDIEN \u{00B7} AUJOURD'HUI", "デイリーチャレンジ · 本日") }
    var dailyAccumContext:       String { t("DAILY CHALLENGE \u{00B7} ALL-TIME", "DESAFÍO DIARIO \u{00B7} ACUMULADO","DÉFI QUOTIDIEN \u{00B7} CUMULÉ", "デイリーチャレンジ · 累計") }
    var leaderboardAllTiers:     String { t("ALL",                           "TODAS",                                 "TOUTES", "全て") }
    var leaderboardPoints:       String { t("points",                        "puntos",                                "points", "ポイント") }
    var leaderboardYou:          String { t("You",                           "Tú",                                    "Toi", "あなた") }
    var inviteFriends:           String { t("CHALLENGE A FRIEND",            "RETAR A UN AMIGO",                      "DÉFIER UN AMI", "フレンドに挑戦") }
    func rankingCount(_ n: Int) -> String { t("Ranking · \(n) players",      "Ranking · \(n) jugadores",              "Ranking · \(n) joueurs", "ランキング · \(n)人") }
    func ptsToNextRank(_ pts: String, _ rank: Int) -> String { t("↑ \(pts) pts to reach #\(rank)", "↑ \(pts) pts para alcanzar #\(rank)", "↑ \(pts) pts pour atteindre #\(rank)", "↑ \(pts) pts で #\(rank) に到達") }
    func paywallCtaBuy(_ price: String) -> String { t("Unlock for \(price)", "Desbloquear por \(price)", "Débloquer pour \(price)", "\(price)で解放") }
    var paywallCtaRestore:      String { t("Restore Purchases",                "Restaurar compras",                     "Restaurer les achats", "購入を復元") }
    var paywallLegal:           String { t("One-time payment. No subscriptions.", "Pago único. Sin suscripciones.",     "Paiement unique. Sans abonnement.", "買い切り。サブスクリプションなし。") }
    var paywallLoading:         String { t("Loading…",                         "Cargando…",                             "Chargement…", "読み込み中…") }

    // MARK: - Daily limit screen
    var limitTitle:             String { t("Missions exhausted",                       "Misiones agotadas",                        "Missions épuisées", "ミッション消化済み") }
    var limitSubtitle:          String { t("You've completed your 3 missions for today","Has completado tus 3 misiones de hoy",     "Vous avez terminé vos 3 missions du jour", "本日の3ミッションを完了しました") }
    func limitCountdown(_ time: String) -> String { t("New missions in \(time)", "Nuevas misiones en \(time)", "Nouvelles missions dans \(time)", "新ミッションまで \(time)") }
    var limitCtaUnlock:         String { t("Unlock full game",                 "Desbloquear juego completo",            "Débloquer le jeu complet", "フルゲームを解放") }
    var limitCtaWait:           String { t("Wait until tomorrow",              "Esperar a mañana",                      "Attendre demain", "明日まで待つ") }

    // MARK: - Purchase states
    var purchaseSuccessTitle:   String { t("Game unlocked!",                   "¡Juego desbloqueado!",                  "Jeu débloqué !", "ゲーム解放！") }
    var purchaseSuccessMessage: String { t("Enjoy all 330 levels without limits.","Disfruta de los 330 niveles sin límites.","Profitez des 330 niveaux sans limite.", "330レベルすべてを制限なしでお楽しみください。") }
    var purchaseRestoredTitle:  String { t("Purchase restored",                "Compra restaurada",                     "Achat restauré", "購入復元完了") }
    var purchaseRestoredMessage: String { t("Your full access has been restored.","Tu acceso completo ha sido restaurado.","Votre accès complet a été restauré.", "フルアクセスが復元されました。") }
    var purchaseErrorTitle:     String { t("Purchase failed",                  "No se pudo completar la compra",        "Échec de l'achat", "購入に失敗しました") }
    var purchaseErrorGeneric:   String { t("Please try again later.",          "Inténtalo de nuevo más tarde.",         "Veuillez réessayer plus tard.", "後でもう一度お試しください。") }
    var purchaseErrorCancelled: String { t("Purchase cancelled.",              "Compra cancelada.",                     "Achat annulé.", "購入がキャンセルされました。") }
    var purchaseErrorNetwork:   String { t("No connection. Check your network.","Sin conexión. Revisa tu red.",         "Pas de connexion. Vérifiez votre réseau.", "接続がありません。ネットワークを確認してください。") }
    var purchaseErrorNotAllowed: String { t("In-app purchases are restricted on this device.","Las compras están restringidas en este dispositivo.","Les achats intégrés sont restreints sur cet appareil.", "このデバイスではApp内課金が制限されています。") }
    var purchaseAlreadyOwned:   String { t("You already own the full game.",   "Ya tienes el juego completo.",          "Vous possédez déjà le jeu complet.", "すでにフルゲームを所有しています。") }
    var purchaseProductMissing: String { t("Product not available. Try again later.", "Producto no disponible. Inténtalo más tarde.", "Produit non disponible. Réessayez plus tard.", "商品が利用できません。後でもう一度お試しください。") }
    var purchaseRestoreNone:   String { t("No previous purchase found.",      "No se encontró ninguna compra anterior.","Aucun achat précédent trouvé.", "以前の購入が見つかりません。") }

    // MARK: - Discount codes
    var discountCodePlaceholder: String { t("Discount code",     "Código de descuento", "Code de réduction", "割引コード") }
    var applyCode:               String { t("APPLY",             "APLICAR",             "APPLIQUER", "適用") }
    var discountValid:           String { t("Code applied",      "Código aplicado",     "Code appliqué", "コード適用済み") }
    var discountInvalid:         String { t("Invalid code",      "Código inválido",     "Code invalide", "無効なコード") }
    var discountExpired:         String { t("Code expired",      "Código expirado",     "Code expiré", "期限切れコード") }
    var discountInactive:        String { t("Code not active",   "Código inactivo",     "Code inactif", "無効なコード") }
    var discountExhausted:       String { t("Usage limit reached","Límite de usos alcanzado","Limite d'utilisations atteinte", "使用回数上限に達しました") }
    func discountOff(_ pct: Int) -> String { t("\(pct)% off", "\(pct)% de descuento", "\(pct)% de réduction", "\(pct)%オフ") }
    func discountedPrice(original: String, discounted: String) -> String {
        t("\(original) → \(discounted)", "\(original) → \(discounted)", "\(original) → \(discounted)", "\(original) → \(discounted)")
    }

    // MARK: - Legal
    var legalSection:    String { t("LEGAL",                "LEGAL",                 "LÉGAL", "法的情報") }
    var termsTitle:      String { t("TERMS & CONDITIONS",   "TÉRMINOS Y CONDICIONES","CONDITIONS D'UTILISATION", "利用規約") }
    var termsSub:        String { t("Usage terms",          "Términos de uso",       "Conditions d'usage", "利用条件") }
    var privacyTitle:    String { t("PRIVACY POLICY",       "POLÍTICA DE PRIVACIDAD","POLITIQUE DE CONFIDENTIALITÉ", "プライバシーポリシー") }
    var privacySub:      String { t("Data & privacy",       "Datos y privacidad",    "Données et vie privée", "データとプライバシー") }

    var termsBody: String {
        t(
            """
            SIGNAL VOID — TERMS & CONDITIONS

            Last updated: April 2025

            1. ACCEPTANCE
            By downloading, installing, or using Signal Void ("the App"), you agree to these Terms & Conditions. If you do not agree, do not use the App.

            2. LICENSE
            We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial entertainment on Apple devices you own or control, subject to the Apple Licensed Application End User License Agreement (EULA).

            3. FREE AND PREMIUM ACCESS
            The App offers a free tier with a limited number of daily missions. After the introductory period, free users may play a set number of missions per day with a cooldown period between sessions. A one-time in-app purchase ("Unlimited Access") removes all daily limits permanently.

            4. IN-APP PURCHASES
            The App offers an optional one-time purchase processed exclusively by Apple through the App Store. All transactions are subject to Apple's terms and conditions. Purchases are non-refundable except as required by applicable law. Refund requests must be directed to Apple. The purchase is tied to your Apple ID and can be restored on any device signed into the same account.

            5. APPLE GAME CENTER
            The App integrates with Apple Game Center for leaderboard functionality. By using this feature you agree to Apple's Game Center terms. No additional account creation is required by Signal Void.

            6. ICLOUD SYNC
            If iCloud is enabled on your device, the App may sync your game progress (mission completions, scores, and progression data) to your personal iCloud account. This sync is managed entirely by Apple's infrastructure. You can disable this in your device's Settings > iCloud.

            7. USER CONDUCT
            You agree not to: reverse-engineer, decompile, or disassemble the App; use the App for unlawful purposes; exploit bugs or glitches to gain unfair advantages; attempt to circumvent daily play limits or purchase verification; distribute modified versions of the App.

            8. INTELLECTUAL PROPERTY
            All content, code, graphics, audio, music, and design in the App are the exclusive property of the developer and protected by copyright and intellectual property laws. You may not reproduce, distribute, or create derivative works from any part of the App without prior written permission.

            9. DISCLAIMERS
            The App is provided "as is" without warranties of any kind, express or implied. We do not guarantee uninterrupted or error-free operation. Game progress may be lost due to device failure, software updates, or other circumstances beyond our control. We reserve the right to modify, suspend, or discontinue the App at any time without notice.

            10. LIMITATION OF LIABILITY
            To the maximum extent permitted by applicable law, the developer shall not be liable for any indirect, incidental, special, or consequential damages arising from or related to the use or inability to use the App, including but not limited to loss of game progress or data.

            11. GOVERNING LAW
            These Terms are governed by the laws of Spain. Any disputes arising from or related to these Terms shall be subject to the exclusive jurisdiction of the courts of Spain, without prejudice to mandatory consumer protection laws of your country of residence.

            12. CHANGES
            We may update these Terms at any time by publishing a new version within the App. Continued use after changes constitutes acceptance of the updated Terms.

            13. CONTACT
            For questions about these Terms, contact: marcosnovodev@gmail.com
            """,
            """
            SIGNAL VOID — TÉRMINOS Y CONDICIONES

            Última actualización: Abril 2025

            1. ACEPTACIÓN
            Al descargar, instalar o usar Signal Void ("la App"), aceptas estos Términos y Condiciones. Si no estás de acuerdo, no uses la App.

            2. LICENCIA
            Te otorgamos una licencia limitada, no exclusiva, intransferible y revocable para usar la App con fines de entretenimiento personal y no comercial en dispositivos Apple que poseas o controles, sujeta al Acuerdo de Licencia de Usuario Final (EULA) de Apple.

            3. ACCESO GRATUITO Y PREMIUM
            La App ofrece un nivel gratuito con un número limitado de misiones diarias. Tras el periodo introductorio, los usuarios gratuitos pueden jugar un número determinado de misiones por día con un periodo de espera entre sesiones. Una compra única ("Acceso Ilimitado") elimina todos los límites diarios de forma permanente.

            4. COMPRAS DENTRO DE LA APP
            La App ofrece una compra opcional única procesada exclusivamente por Apple a través de la App Store. Todas las transacciones están sujetas a los términos y condiciones de Apple. Las compras no son reembolsables, excepto cuando lo exija la ley aplicable. Las solicitudes de reembolso deben dirigirse a Apple. La compra está vinculada a tu Apple ID y puede restaurarse en cualquier dispositivo con la misma cuenta.

            5. APPLE GAME CENTER
            La App se integra con Apple Game Center para la funcionalidad de clasificaciones. Al usar esta función, aceptas los términos de Game Center de Apple. Signal Void no requiere la creación de cuentas adicionales.

            6. SINCRONIZACIÓN ICLOUD
            Si iCloud está habilitado en tu dispositivo, la App puede sincronizar tu progreso de juego (misiones completadas, puntuaciones y datos de progresión) en tu cuenta personal de iCloud. Esta sincronización es gestionada íntegramente por la infraestructura de Apple. Puedes desactivarla en Ajustes > iCloud de tu dispositivo.

            7. CONDUCTA DEL USUARIO
            Te comprometes a no: realizar ingeniería inversa, descompilar o desensamblar la App; usar la App con fines ilegales; explotar errores o fallos para obtener ventajas injustas; intentar eludir los límites diarios de juego o la verificación de compras; distribuir versiones modificadas de la App.

            8. PROPIEDAD INTELECTUAL
            Todo el contenido, código, gráficos, audio, música y diseño de la App son propiedad exclusiva del desarrollador y están protegidos por las leyes de derechos de autor y propiedad intelectual. No puedes reproducir, distribuir ni crear obras derivadas de ninguna parte de la App sin permiso previo por escrito.

            9. DESCARGOS DE RESPONSABILIDAD
            La App se proporciona "tal cual", sin garantías de ningún tipo, expresas o implícitas. No garantizamos un funcionamiento ininterrumpido ni libre de errores. El progreso del juego puede perderse debido a fallos del dispositivo, actualizaciones de software u otras circunstancias fuera de nuestro control. Nos reservamos el derecho de modificar, suspender o descontinuar la App en cualquier momento sin previo aviso.

            10. LIMITACIÓN DE RESPONSABILIDAD
            En la máxima medida permitida por la ley aplicable, el desarrollador no será responsable de ningún daño indirecto, incidental, especial o consecuente derivado de o relacionado con el uso o la imposibilidad de uso de la App, incluyendo pero no limitado a la pérdida de progreso o datos del juego.

            11. LEY APLICABLE
            Estos Términos se rigen por las leyes de España. Cualquier disputa derivada de o relacionada con estos Términos estará sujeta a la jurisdicción exclusiva de los tribunales de España, sin perjuicio de las leyes obligatorias de protección al consumidor de tu país de residencia.

            12. CAMBIOS
            Podemos actualizar estos Términos en cualquier momento publicando una nueva versión dentro de la App. El uso continuado tras los cambios constituye la aceptación de los Términos actualizados.

            13. CONTACTO
            Para preguntas sobre estos Términos, contacta: marcosnovodev@gmail.com
            """,
            """
            SIGNAL VOID — CONDITIONS D'UTILISATION

            Dernière mise à jour : Avril 2025

            1. ACCEPTATION
            En téléchargeant, installant ou utilisant Signal Void (« l'Application »), vous acceptez les présentes Conditions d'Utilisation. Si vous n'êtes pas d'accord, n'utilisez pas l'Application.

            2. LICENCE
            Nous vous accordons une licence limitée, non exclusive, non transférable et révocable pour utiliser l'Application à des fins de divertissement personnel et non commercial sur des appareils Apple que vous possédez ou contrôlez, conformément au Contrat de Licence Utilisateur Final (EULA) d'Apple.

            3. ACCÈS GRATUIT ET PREMIUM
            L'Application propose un niveau gratuit avec un nombre limité de missions quotidiennes. Après la période d'introduction, les utilisateurs gratuits peuvent jouer un nombre défini de missions par jour avec un délai d'attente entre les sessions. Un achat unique (« Accès Illimité ») supprime définitivement toutes les limites quotidiennes.

            4. ACHATS INTÉGRÉS
            L'Application propose un achat unique optionnel traité exclusivement par Apple via l'App Store. Toutes les transactions sont soumises aux conditions générales d'Apple. Les achats ne sont pas remboursables, sauf si la loi l'exige. Les demandes de remboursement doivent être adressées à Apple. L'achat est lié à votre identifiant Apple et peut être restauré sur tout appareil connecté au même compte.

            5. APPLE GAME CENTER
            L'Application s'intègre à Apple Game Center pour la fonctionnalité de classement. En utilisant cette fonctionnalité, vous acceptez les conditions de Game Center d'Apple. Signal Void ne nécessite aucune création de compte supplémentaire.

            6. SYNCHRONISATION ICLOUD
            Si iCloud est activé sur votre appareil, l'Application peut synchroniser votre progression (missions terminées, scores et données de progression) dans votre compte iCloud personnel. Cette synchronisation est entièrement gérée par l'infrastructure d'Apple. Vous pouvez la désactiver dans Réglages > iCloud de votre appareil.

            7. CONDUITE DE L'UTILISATEUR
            Vous vous engagez à ne pas : effectuer de rétro-ingénierie, décompiler ou désassembler l'Application ; utiliser l'Application à des fins illégales ; exploiter des bugs ou des failles pour obtenir des avantages injustes ; tenter de contourner les limites quotidiennes de jeu ou la vérification des achats ; distribuer des versions modifiées de l'Application.

            8. PROPRIÉTÉ INTELLECTUELLE
            Tout le contenu, le code, les graphismes, l'audio, la musique et le design de l'Application sont la propriété exclusive du développeur et protégés par les lois sur le droit d'auteur et la propriété intellectuelle. Vous ne pouvez reproduire, distribuer ni créer d'œuvres dérivées d'aucune partie de l'Application sans autorisation écrite préalable.

            9. CLAUSE DE NON-RESPONSABILITÉ
            L'Application est fournie « en l'état », sans garantie d'aucune sorte, expresse ou implicite. Nous ne garantissons pas un fonctionnement ininterrompu ou exempt d'erreurs. La progression du jeu peut être perdue en raison de pannes d'appareil, de mises à jour logicielles ou d'autres circonstances indépendantes de notre volonté. Nous nous réservons le droit de modifier, suspendre ou interrompre l'Application à tout moment sans préavis.

            10. LIMITATION DE RESPONSABILITÉ
            Dans la mesure maximale permise par la loi applicable, le développeur ne pourra être tenu responsable de tout dommage indirect, accessoire, spécial ou consécutif découlant de ou lié à l'utilisation ou l'impossibilité d'utiliser l'Application, y compris mais sans s'y limiter, la perte de progression ou de données de jeu.

            11. LOI APPLICABLE
            Les présentes Conditions sont régies par les lois d'Espagne. Tout litige découlant de ou lié aux présentes Conditions sera soumis à la compétence exclusive des tribunaux d'Espagne, sans préjudice des lois impératives de protection des consommateurs de votre pays de résidence.

            12. MODIFICATIONS
            Nous pouvons mettre à jour ces Conditions à tout moment en publiant une nouvelle version dans l'Application. L'utilisation continue après les modifications vaut acceptation des Conditions mises à jour.

            13. CONTACT
            Pour toute question concernant ces Conditions, contactez : marcosnovodev@gmail.com
            """,
            """
            SIGNAL VOID — 利用規約

            最終更新日: 2025年4月

            1. 同意
            Signal Void（以下「本アプリ」）をダウンロード、インストール、または使用することにより、お客様は本利用規約に同意したものとみなされます。同意いただけない場合は、本アプリを使用しないでください。

            2. ライセンス
            当社は、お客様が所有または管理するAppleデバイスにおいて、個人的かつ非商用の娯楽目的で本アプリを使用するための、限定的、非独占的、譲渡不可、取消可能なライセンスを付与します。このライセンスはAppleのライセンスアプリケーションエンドユーザー使用許諾契約（EULA）に準拠します。

            3. 無料アクセスとプレミアムアクセス
            本アプリは、1日あたりのミッション数が制限された無料プランを提供しています。導入期間終了後、無料ユーザーは1日あたり一定数のミッションをプレイでき、セッション間にクールダウン期間があります。ワンタイム購入（「無制限アクセス」）により、すべての日次制限が永久に解除されます。

            4. アプリ内課金
            本アプリは、App Storeを通じてAppleが独占的に処理するオプションのワンタイム購入を提供しています。すべての取引はAppleの利用規約に従います。購入は、適用法で求められる場合を除き、返金不可です。返金リクエストはAppleに直接お問い合わせください。購入はお客様のApple IDに紐づけられ、同じアカウントでサインインしたすべてのデバイスで復元可能です。

            5. APPLE GAME CENTER
            本アプリは、リーダーボード機能のためにApple Game Centerと連携しています。この機能を使用することで、お客様はAppleのGame Center規約に同意したことになります。Signal Voidでは追加のアカウント作成は不要です。

            6. ICLOUD同期
            お使いのデバイスでiCloudが有効な場合、本アプリはゲームの進捗（ミッション完了、スコア、進行データ）をお客様のiCloudアカウントに同期する場合があります。この同期はAppleのインフラストラクチャにより完全に管理されています。設定 > iCloudから無効にできます。

            7. ユーザーの行動
            お客様は以下の行為を行わないことに同意します：本アプリのリバースエンジニアリング、逆コンパイル、逆アセンブル；違法目的での本アプリの使用；不正な優位性を得るためのバグやグリッチの悪用；日次プレイ制限や購入検証の回避の試み；本アプリの改変版の配布。

            8. 知的財産
            本アプリのすべてのコンテンツ、コード、グラフィック、オーディオ、音楽、デザインは開発者の独占的財産であり、著作権法および知的財産法により保護されています。事前の書面による許可なく、本アプリの一部を複製、配布、または二次的著作物を作成することはできません。

            9. 免責事項
            本アプリは「現状有姿」で提供され、明示的または黙示的を問わず、いかなる種類の保証もありません。中断なくエラーのない動作を保証するものではありません。デバイスの故障、ソフトウェアの更新、またはその他の当社の管理外の事情により、ゲームの進捗が失われる場合があります。当社は、予告なくいつでも本アプリを変更、一時停止、または中止する権利を留保します。

            10. 責任の制限
            適用法が許容する最大限の範囲において、開発者は、ゲームの進捗やデータの喪失を含むがこれに限定されない、本アプリの使用または使用不能に起因するいかなる間接的、付随的、特別、または結果的損害についても責任を負いません。

            11. 準拠法
            本規約はスペインの法律に準拠します。本規約に起因するまたは関連するいかなる紛争も、お客様の居住国の強行的消費者保護法を害することなく、スペインの裁判所の専属管轄に服するものとします。

            12. 変更
            当社は、本アプリ内に新バージョンを公開することにより、本規約をいつでも更新することができます。変更後の継続使用は、更新された規約の承諾を意味します。

            13. お問い合わせ
            本規約に関するご質問は、marcosnovodev@gmail.com までご連絡ください。
            """
        )
    }

    var privacyBody: String {
        t(
            """
            SIGNAL VOID — PRIVACY POLICY

            Last updated: April 2025

            1. OVERVIEW
            Signal Void ("the App") is designed with privacy as a core principle. We do not require user accounts, do not collect personal information, and do not send data to external servers.

            2. DATA PROCESSED BY APPLE SERVICES
            The App integrates exclusively with Apple's own services. The developer does not have direct access to the data processed by these services:
            • Apple Game Center — Your Game Center alias and efficiency scores are shared with Apple for leaderboard functionality. This data is governed by Apple's Privacy Policy.
            • iCloud — If enabled on your device, your game progress (mission completions, scores, planet passes, and progression data) is synced to your personal iCloud account. You can manage or delete this data in Settings > [your name] > iCloud.
            • App Store — If you make the optional in-app purchase, Apple processes the transaction. We do not receive or store any payment information.

            3. DATA STORED ON YOUR DEVICE
            The App stores the following data locally on your device using standard system storage:
            • Game progress (completed missions, scores, efficiency ratings)
            • User preferences (sound, music, haptics, language, motion settings)
            • Session data (daily play counts, cooldown timers)
            This data remains on your device and is not transmitted to any external server.

            4. DATA WE DO NOT COLLECT
            We do not collect, store, or transmit: names, email addresses, phone numbers, location data, device identifiers, advertising identifiers (IDFA), usage analytics, crash reports, or any personally identifiable information. The App does not use Apple's App Tracking Transparency framework because no tracking occurs.

            5. LOCAL NOTIFICATIONS
            The App may request permission to send local notifications (e.g., to inform you when a cooldown period ends). These notifications are generated and stored entirely on your device. No notification data is sent to external servers. You can disable notifications at any time in Settings > Notifications > Signal Void.

            6. THIRD-PARTY SERVICES
            The App does not integrate any third-party analytics, advertising, crash reporting, or tracking services. All functionality is provided through Apple's native frameworks.

            7. CHILDREN'S PRIVACY
            The App does not knowingly collect personal data from anyone, including children under the age of 13 (or applicable age in your jurisdiction). The minimal data processing described above (all handled by Apple's services) applies equally to all users regardless of age.

            8. DATA RETENTION AND DELETION
            Since we do not collect data on external servers, there is no data for us to retain or delete. Local game data can be removed by deleting the App from your device. iCloud data can be managed through your device's iCloud settings.

            9. INTERNATIONAL USERS
            The App does not transfer personal data across borders because it does not collect personal data. All data storage is either local to your device or within your personal iCloud account, managed by Apple according to their data processing policies.

            10. YOUR RIGHTS (GDPR / CCPA)
            Under the EU General Data Protection Regulation (GDPR) and the California Consumer Privacy Act (CCPA), you have rights regarding your personal data. Since Signal Void does not collect personal data, these rights are inherently fulfilled. For data stored by Apple's services (Game Center, iCloud, App Store), please refer to Apple's Privacy Policy and your device settings.

            11. CHANGES
            We may update this Privacy Policy at any time by publishing a new version within the App. Continued use after changes constitutes acceptance.

            12. CONTACT
            For privacy-related questions, contact: marcosnovodev@gmail.com
            """,
            """
            SIGNAL VOID — POLÍTICA DE PRIVACIDAD

            Última actualización: Abril 2025

            1. DESCRIPCIÓN GENERAL
            Signal Void ("la App") está diseñada con la privacidad como principio fundamental. No requerimos cuentas de usuario, no recopilamos información personal y no enviamos datos a servidores externos.

            2. DATOS PROCESADOS POR SERVICIOS DE APPLE
            La App se integra exclusivamente con los propios servicios de Apple. El desarrollador no tiene acceso directo a los datos procesados por estos servicios:
            • Apple Game Center — Tu alias y puntuaciones de eficiencia de Game Center se comparten con Apple para la funcionalidad de clasificaciones. Estos datos se rigen por la Política de Privacidad de Apple.
            • iCloud — Si está habilitado en tu dispositivo, tu progreso de juego (misiones completadas, puntuaciones, pases planetarios y datos de progresión) se sincroniza en tu cuenta personal de iCloud. Puedes gestionar o eliminar estos datos en Ajustes > [tu nombre] > iCloud.
            • App Store — Si realizas la compra opcional, Apple procesa la transacción. No recibimos ni almacenamos ninguna información de pago.

            3. DATOS ALMACENADOS EN TU DISPOSITIVO
            La App almacena los siguientes datos localmente en tu dispositivo mediante el almacenamiento estándar del sistema:
            • Progreso del juego (misiones completadas, puntuaciones, calificaciones de eficiencia)
            • Preferencias de usuario (sonido, música, hápticos, idioma, ajustes de movimiento)
            • Datos de sesión (conteo de partidas diarias, temporizadores de espera)
            Estos datos permanecen en tu dispositivo y no se transmiten a ningún servidor externo.

            4. DATOS QUE NO RECOPILAMOS
            No recopilamos, almacenamos ni transmitimos: nombres, direcciones de correo electrónico, números de teléfono, datos de ubicación, identificadores de dispositivo, identificadores publicitarios (IDFA), análisis de uso, informes de errores ni ninguna información de identificación personal. La App no utiliza el framework App Tracking Transparency de Apple porque no se realiza ningún seguimiento.

            5. NOTIFICACIONES LOCALES
            La App puede solicitar permiso para enviar notificaciones locales (por ejemplo, para informarte cuando termina un periodo de espera). Estas notificaciones se generan y almacenan completamente en tu dispositivo. No se envían datos de notificación a servidores externos. Puedes desactivar las notificaciones en cualquier momento en Ajustes > Notificaciones > Signal Void.

            6. SERVICIOS DE TERCEROS
            La App no integra ningún servicio de análisis, publicidad, informes de errores ni seguimiento de terceros. Toda la funcionalidad se proporciona a través de los frameworks nativos de Apple.

            7. PRIVACIDAD DE MENORES
            La App no recopila conscientemente datos personales de nadie, incluidos menores de 13 años (o la edad aplicable en tu jurisdicción). El procesamiento mínimo de datos descrito anteriormente (todo gestionado por los servicios de Apple) se aplica por igual a todos los usuarios independientemente de su edad.

            8. RETENCIÓN Y ELIMINACIÓN DE DATOS
            Dado que no recopilamos datos en servidores externos, no hay datos que retener o eliminar por nuestra parte. Los datos locales del juego pueden eliminarse borrando la App de tu dispositivo. Los datos de iCloud pueden gestionarse a través de los ajustes de iCloud de tu dispositivo.

            9. USUARIOS INTERNACIONALES
            La App no transfiere datos personales a través de fronteras porque no recopila datos personales. Todo el almacenamiento de datos es local en tu dispositivo o dentro de tu cuenta personal de iCloud, gestionada por Apple según sus políticas de procesamiento de datos.

            10. TUS DERECHOS (RGPD / CCPA)
            Bajo el Reglamento General de Protección de Datos (RGPD) de la UE y la Ley de Privacidad del Consumidor de California (CCPA), tienes derechos sobre tus datos personales. Dado que Signal Void no recopila datos personales, estos derechos se cumplen inherentemente. Para datos almacenados por los servicios de Apple (Game Center, iCloud, App Store), consulta la Política de Privacidad de Apple y los ajustes de tu dispositivo.

            11. CAMBIOS
            Podemos actualizar esta Política de Privacidad en cualquier momento publicando una nueva versión dentro de la App. El uso continuado tras los cambios constituye su aceptación.

            12. CONTACTO
            Para preguntas relacionadas con la privacidad, contacta: marcosnovodev@gmail.com
            """,
            """
            SIGNAL VOID — POLITIQUE DE CONFIDENTIALITÉ

            Dernière mise à jour : Avril 2025

            1. APERÇU
            Signal Void (« l'Application ») est conçue avec le respect de la vie privée comme principe fondamental. Nous ne nécessitons pas de compte utilisateur, ne collectons pas d'informations personnelles et n'envoyons pas de données à des serveurs externes.

            2. DONNÉES TRAITÉES PAR LES SERVICES APPLE
            L'Application s'intègre exclusivement aux propres services d'Apple. Le développeur n'a pas d'accès direct aux données traitées par ces services :
            • Apple Game Center — Votre alias et vos scores d'efficacité Game Center sont partagés avec Apple pour la fonctionnalité de classement. Ces données sont régies par la Politique de Confidentialité d'Apple.
            • iCloud — Si activé sur votre appareil, votre progression (missions terminées, scores, laissez-passer planétaires et données de progression) est synchronisée dans votre compte iCloud personnel. Vous pouvez gérer ou supprimer ces données dans Réglages > [votre nom] > iCloud.
            • App Store — Si vous effectuez l'achat optionnel, Apple traite la transaction. Nous ne recevons ni ne stockons aucune information de paiement.

            3. DONNÉES STOCKÉES SUR VOTRE APPAREIL
            L'Application stocke les données suivantes localement sur votre appareil via le stockage système standard :
            • Progression du jeu (missions terminées, scores, notes d'efficacité)
            • Préférences utilisateur (son, musique, haptique, langue, réglages de mouvement)
            • Données de session (compteur de parties quotidiennes, minuteries d'attente)
            Ces données restent sur votre appareil et ne sont transmises à aucun serveur externe.

            4. DONNÉES QUE NOUS NE COLLECTONS PAS
            Nous ne collectons, ne stockons ni ne transmettons : noms, adresses e-mail, numéros de téléphone, données de localisation, identifiants d'appareil, identifiants publicitaires (IDFA), analyses d'utilisation, rapports de plantage, ni aucune information personnelle identifiable. L'Application n'utilise pas le framework App Tracking Transparency d'Apple car aucun suivi n'est effectué.

            5. NOTIFICATIONS LOCALES
            L'Application peut demander l'autorisation d'envoyer des notifications locales (par exemple, pour vous informer de la fin d'un délai d'attente). Ces notifications sont générées et stockées entièrement sur votre appareil. Aucune donnée de notification n'est envoyée à des serveurs externes. Vous pouvez désactiver les notifications à tout moment dans Réglages > Notifications > Signal Void.

            6. SERVICES TIERS
            L'Application n'intègre aucun service d'analyse, de publicité, de rapport de plantage ou de suivi tiers. Toutes les fonctionnalités sont fournies via les frameworks natifs d'Apple.

            7. VIE PRIVÉE DES ENFANTS
            L'Application ne collecte sciemment aucune donnée personnelle de quiconque, y compris des enfants de moins de 13 ans (ou l'âge applicable dans votre juridiction). Le traitement minimal des données décrit ci-dessus (entièrement géré par les services d'Apple) s'applique également à tous les utilisateurs, quel que soit leur âge.

            8. CONSERVATION ET SUPPRESSION DES DONNÉES
            Comme nous ne collectons pas de données sur des serveurs externes, il n'y a pas de données à conserver ou supprimer de notre côté. Les données locales du jeu peuvent être supprimées en désinstallant l'Application de votre appareil. Les données iCloud peuvent être gérées via les réglages iCloud de votre appareil.

            9. UTILISATEURS INTERNATIONAUX
            L'Application ne transfère pas de données personnelles au-delà des frontières car elle ne collecte pas de données personnelles. Tout le stockage de données est soit local sur votre appareil, soit dans votre compte iCloud personnel, géré par Apple conformément à ses politiques de traitement des données.

            10. VOS DROITS (RGPD / CCPA)
            En vertu du Règlement Général sur la Protection des Données (RGPD) de l'UE et du California Consumer Privacy Act (CCPA), vous disposez de droits concernant vos données personnelles. Comme Signal Void ne collecte pas de données personnelles, ces droits sont intrinsèquement respectés. Pour les données stockées par les services d'Apple (Game Center, iCloud, App Store), veuillez consulter la Politique de Confidentialité d'Apple et les réglages de votre appareil.

            11. MODIFICATIONS
            Nous pouvons mettre à jour cette Politique de Confidentialité à tout moment en publiant une nouvelle version dans l'Application. L'utilisation continue après les modifications vaut acceptation.

            12. CONTACT
            Pour toute question relative à la vie privée, contactez : marcosnovodev@gmail.com
            """,
            """
            SIGNAL VOID — プライバシーポリシー

            最終更新日: 2025年4月

            1. 概要
            Signal Void（以下「本アプリ」）は、プライバシーを基本原則として設計されています。ユーザーアカウントは不要であり、個人情報の収集や外部サーバーへのデータ送信は行いません。

            2. APPLEサービスによるデータ処理
            本アプリはApple独自のサービスとのみ連携しています。開発者はこれらのサービスが処理するデータに直接アクセスすることはありません。
            • Apple Game Center — Game Centerのエイリアスと効率スコアは、リーダーボード機能のためにAppleと共有されます。このデータはAppleのプライバシーポリシーに準拠します。
            • iCloud — デバイスでiCloudが有効な場合、ゲームの進捗（ミッション完了、スコア、惑星パス、進行データ）がiCloudアカウントに同期されます。設定 > [ユーザー名] > iCloudでデータを管理・削除できます。
            • App Store — オプションのアプリ内課金を行った場合、Appleが取引を処理します。当社は支払い情報を受信・保存しません。

            3. デバイスに保存されるデータ
            本アプリは以下のデータをデバイスのローカルストレージに保存します：
            • ゲームの進捗（完了ミッション、スコア、効率評価）
            • ユーザー設定（サウンド、音楽、触覚、言語、モーション設定）
            • セッションデータ（デイリープレイ回数、クールダウンタイマー）
            このデータはデバイス上に残り、外部サーバーに送信されることはありません。

            4. 当社が収集しないデータ
            氏名、メールアドレス、電話番号、位置データ、デバイス識別子、広告識別子（IDFA）、利用分析、クラッシュレポート、その他の個人を特定可能な情報の収集、保存、送信は行いません。トラッキングが発生しないため、AppleのApp Tracking Transparencyフレームワークは使用しません。

            5. ローカル通知
            本アプリは、ローカル通知の送信許可を求める場合があります（クールダウン期間の終了通知など）。これらの通知はデバイス上で完全に生成・保存されます。通知データは外部サーバーに送信されません。設定 > 通知 > Signal Voidからいつでも通知を無効にできます。

            6. サードパーティサービス
            本アプリは、サードパーティの分析、広告、クラッシュレポート、トラッキングサービスを一切使用しません。すべての機能はAppleのネイティブフレームワークを通じて提供されます。

            7. 児童のプライバシー
            本アプリは、13歳未満の子供（または管轄地域で適用される年齢）を含め、いかなる人物からも意図的に個人データを収集しません。上記の最小限のデータ処理（すべてAppleのサービスにより処理）は、年齢に関係なくすべてのユーザーに同様に適用されます。

            8. データの保持と削除
            外部サーバーでデータを収集しないため、当社が保持または削除するデータはありません。ローカルゲームデータはデバイスからアプリを削除することで消去できます。iCloudデータはデバイスのiCloud設定から管理できます。

            9. 海外ユーザー
            本アプリは個人データを収集しないため、国境を越えた個人データの転送は行いません。すべてのデータストレージはデバイスのローカル、またはAppleのデータ処理ポリシーに基づいて管理される個人iCloudアカウント内にあります。

            10. お客様の権利（GDPR / CCPA）
            EUの一般データ保護規則（GDPR）およびカリフォルニア州消費者プライバシー法（CCPA）の下、お客様は個人データに関する権利を有します。Signal Voidは個人データを収集しないため、これらの権利は本質的に満たされています。Appleのサービス（Game Center、iCloud、App Store）により保存されたデータについては、Appleのプライバシーポリシーおよびデバイスの設定をご確認ください。

            11. 変更
            当社は、本アプリ内に新バージョンを公開することにより、本プライバシーポリシーをいつでも更新することができます。変更後の継続使用は承諾を意味します。

            12. お問い合わせ
            プライバシーに関するご質問は、marcosnovodev@gmail.com までご連絡ください。
            """
        )
    }

    // MARK: - Local notifications
    var notifCooldownTitle: String { t("The network is live again",
                                       "La red vuelve a estar disponible",
                                       "Le réseau est de nouveau disponible",
                                       "ネットワークが再び稼働しています") }
    var notifCooldownBody:  String { t("You can play again in Signal Void.",
                                       "Ya puedes volver a jugar en Signal Void.",
                                       "Vous pouvez rejouer dans Signal Void.",
                                       "Signal Voidで再びプレイできます。") }

    // MARK: - Home V2 / V3
    var play:        String { t("PLAY",          "JUGAR",               "JOUER", "プレイ") }
    var viewFullMap: String { t("VIEW FULL MAP", "VER MAPA COMPLETO",   "VOIR LA CARTE COMPLÈTE", "全体マップを表示") }
    var inProgress:  String { t("IN PROGRESS",   "EN PROGRESO",         "EN COURS", "進行中") }
    func resumeMissionLabel(_ id: String) -> String {
        t("CONTINUE MISSION \(id)", "CONTINUAR MISIÓN \(id)", "CONTINUER MISSION \(id)", "ミッション\(id)を再開")
    }
    func missionsCompleted(done: Int, total: Int) -> String {
        t("\(done) of \(total) missions completed",
          "\(done) de \(total) misiones completadas",
          "\(done) sur \(total) missions terminées",
          "\(total)中\(done)ミッション完了")
    }
    var missionsCompletedShort: String { t("missions completed", "misiones completadas", "missions terminées", "ミッション完了") }

    // MARK: - Victory telemetry
    var missionDebrief:  String { t("MISSION\nDEBRIEF",  "INFORME\nDE MISIÓN",  "COMPTE-RENDU\nDE MISSION", "ミッション\nレポート") }
    var dailyDebrief:    String { t("DAILY\nCHALLENGE",  "DESAFÍO\nDIARIO",     "DÉFI\nQUOTIDIEN", "デイリー\nチャレンジ") }
    var missionQuality:  String { t("MISSION QUALITY",   "CALIDAD DE MISIÓN",   "QUALITÉ DE MISSION", "ミッション品質") }
    var usedMin:         String { t("USED / MIN",         "USADO / MÍN",         "UTILISÉ / MIN", "使用 / 最小") }
    var missionScore:    String { t("MISSION SCORE",      "PUNTUACIÓN MISIÓN",   "SCORE MISSION", "ミッションスコア") }
    var rankingTotal:    String { t("RANKING TOTAL",      "TOTAL RANKING",       "TOTAL CLASSEMENT", "ランキング合計") }
    var maxLabel:        String { t("MAX",                "MÁX",                 "MAX", "最大") }
    var retryLabel:      String { t("RETRY",              "REINTENTAR",          "RÉESSAYER", "リトライ") }
    var shareLabel:      String { t("SHARE",              "COMPARTIR",           "PARTAGER", "共有") }

    func shareVictoryText(mission: Int, efficiency: Int) -> String {
        t("Mission #\(mission) complete — \(efficiency)% efficiency! Can you beat my score in Signal Void? 🛰️",
          "¡Misión #\(mission) completada — \(efficiency)% de eficiencia! ¿Puedes superar mi puntuación en Signal Void? 🛰️",
          "Mission #\(mission) terminée — \(efficiency)% d'efficacité ! Tu peux battre mon score sur Signal Void ? 🛰️",
          "ミッション#\(mission)完了 — 効率\(efficiency)%！Signal Voidで私のスコアを超えられる？🛰️")
    }

    func shareLeaderboardText(rank: Int, board: String) -> String {
        t("I'm ranked #\(rank) on the \(board) leaderboard in Signal Void! Think you can beat me? 🏆",
          "¡Estoy en el puesto #\(rank) en la clasificación \(board) de Signal Void! ¿Crees que puedes superarme? 🏆",
          "Je suis classé #\(rank) au classement \(board) dans Signal Void ! Tu penses pouvoir me battre ? 🏆",
          "Signal Voidの\(board)ランキングで#\(rank)位！私に勝てると思う？🏆")
    }
    var mapLabel:        String { t("MAP",                "MAPA",                "CARTE", "マップ") }

    func nextMissionLabel(_ displayID: String) -> String {
        t("MISSION \(displayID)", "MISIÓN \(displayID)", "MISSION \(displayID)", "ミッション \(displayID)")
    }

    func routeRating(_ eff: Float) -> String {
        switch eff {
        case 0.95...: return t("OPTIMAL",    "ÓPTIMO",     "OPTIMAL", "最適")
        case 0.80...: return t("EFFICIENT",  "EFICIENTE",  "EFFICACE", "効率的")
        case 0.60...: return t("ADEQUATE",   "ADECUADO",   "ADÉQUAT", "適正")
        default:      return t("SUBOPTIMAL", "SUBÓPTIMO",  "SOUS-OPTIMAL", "準最適")
        }
    }

    func routeMessage(_ eff: Float) -> String {
        switch eff {
        case 0.95...:
            return t("Optimal route achieved.",
                     "Ruta óptima conseguida.",
                     "Route optimale atteinte.",
                     "最適ルートを達成しました。")
        case 0.80...:
            return t("A more efficient route was possible.",
                     "Una ruta más eficiente era posible.",
                     "Un itinéraire plus efficace était possible.",
                     "より効率的なルートが可能でした。")
        case 0.60...:
            return t("Mission complete. A more efficient route was possible.",
                     "Misión completada. Una ruta más eficiente era posible.",
                     "Mission accomplie. Un itinéraire plus efficace était possible.",
                     "ミッション完了。より効率的なルートが可能でした。")
        default:
            return t("You completed the mission, but not with the most efficient network.",
                     "Misión completada, pero la red no fue la más eficiente.",
                     "Mission accomplie, mais le réseau n'était pas le plus efficace.",
                     "ミッション完了。ただし最も効率的なネットワークではありませんでした。")
        }
    }

    // MARK: - Astronaut rank
    func rankTitle(_ level: Int) -> String {
        switch level {
        case 1...2:  return t("CADET",     "CADETE",     "CADET", "訓練生")
        case 3...4:  return t("PILOT",     "PILOTO",     "PILOTE", "パイロット")
        case 5...6:  return t("NAVIGATOR", "NAVEGANTE",  "NAVIGATEUR", "ナビゲーター")
        case 7...9:  return t("COMMANDER", "COMANDANTE", "COMMANDANT", "コマンダー")
        default:     return t("ADMIRAL",   "ALMIRANTE",  "AMIRAL", "アドミラル")
        }
    }

    // MARK: - Anti-frustration messages (loss overlay)
    /// Encouraging micro-message shown from the 2nd consecutive failure onward.
    func frustrationMessage(failures: Int) -> String {
        switch failures {
        case 2:  return t("ALMOST THERE",          "CASI LO TIENES",      "VOUS Y ÊTES PRESQUE", "もう少し")
        case 3:  return t("TRY A DIFFERENT ROUTE",  "PRUEBA OTRA RUTA",    "ESSAYEZ UN AUTRE CHEMIN", "別のルートを試して")
        default: return t("YOU'VE GOT THIS",        "TÚ PUEDES HACERLO",   "VOUS POUVEZ LE FAIRE", "きっとできる")
        }
    }

    // MARK: - Failure cause (loss overlay)
    func failureCauseLabel(_ cause: FailureCause) -> String {
        switch cause {
        case .fragileTileDepleted:   return t("FRAGILE TILE BURNED OUT",   "NODO FRÁGIL AGOTADO",         "NŒUD FRAGILE ÉPUISÉ", "脆弱タイル焼損")
        case .chargeGateIncomplete:  return t("CHARGE GATE NOT ACTIVATED", "COMPUERTA DE CARGA INACTIVA", "PORTE DE CHARGE INACTIVE", "チャージゲート未起動")
        case .coverageInsufficient:  return t("INSUFFICIENT COVERAGE",     "COBERTURA INSUFICIENTE",      "COUVERTURE INSUFFISANTE", "カバー率不足")
        case .moveLimitExhausted:    return t("SIGNAL LOST IN VOID",       "SEÑAL PERDIDA EN EL VACÍO",   "SIGNAL PERDU DANS LE VIDE", "ボイドでシグナル消失")
        }
    }

    func failureCauseHint(_ cause: FailureCause) -> String {
        switch cause {
        case .fragileTileDepleted:   return t("Use this node last",                    "Usa este nodo al final",               "Utilisez ce nœud en dernier", "このノードは最後に使おう")
        case .chargeGateIncomplete:  return t("Activate all gates first",              "Activa todas las compuertas",          "Activez toutes les portes d'abord", "先にすべてのゲートを起動しよう")
        case .coverageInsufficient:  return t("Activate more tiles before connecting", "Activa más bloques antes de conectar", "Activez plus de tuiles avant de connecter", "接続前にもっとタイルを起動しよう")
        case .moveLimitExhausted:    return t("Plan your route before moving",         "Planifica antes de mover",            "Planifiez avant de bouger", "動く前にルートを計画しよう")
        }
    }

    // MARK: - Versus

    // Lobby
    var versus: String             { t("VERSUS",                    "VERSUS",                      "VERSUS", "VERSUS") }
    var versusSubtitle: String     { t("1 v 1  REAL-TIME",          "1 v 1  EN TIEMPO REAL",       "1 v 1  EN TEMPS RÉEL", "1 v 1 リアルタイム") }
    var versusHomeSubtitle: String { t("REAL-TIME MULTIPLAYER",      "MULTIJUGADOR EN TIEMPO REAL", "MULTIJOUEUR EN TEMPS RÉEL", "リアルタイムマルチプレイ") }
    var findMatch: String          { t("FIND MATCH",                "BUSCAR RIVAL",                "TROUVER UN MATCH", "対戦相手を探す") }
    var gameCenterConnected: String { t("GAME CENTER CONNECTED",    "GAME CENTER CONECTADO",       "GAME CENTER CONNECTÉ", "GAME CENTER接続済み") }
    var gameCenterRequired: String { t("GAME CENTER REQUIRED",      "GAME CENTER REQUERIDO",       "GAME CENTER REQUIS", "GAME CENTERが必要") }
    var versusExit: String         { t("EXIT",                      "SALIR",                       "QUITTER", "退出") }
    var versusMatchmakingDisabled: String { t("MATCHMAKING NOT ENABLED", "MATCHMAKING NO ACTIVADO",   "MATCHMAKING NON ACTIVÉ", "マッチメイキング無効") }
    var gameCenterNotAuth: String  { t("GAME CENTER NOT AUTHENTICATED", "GAME CENTER NO AUTENTICADO", "GAME CENTER NON AUTHENTIFIÉ", "GAME CENTER未認証") }
    var versusSoloTest: String     { t("SOLO TEST",                  "PRUEBA LOCAL",                "TEST SOLO", "ソロテスト") }
    var versusSoloHint: String     { t("PLAY AGAINST A BOT — NO SECOND DEVICE NEEDED", "JUEGA CONTRA UN BOT — SIN SEGUNDO DISPOSITIVO", "JOUEZ CONTRE UN BOT — PAS BESOIN D'UN SECOND APPAREIL", "ボットと対戦 — 2台目のデバイス不要") }

    // Search
    var searchingForOpponent: String { t("SEARCHING FOR OPPONENT",  "BUSCANDO RIVAL",              "RECHERCHE D'ADVERSAIRE", "対戦相手を検索中") }
    var versusCancel: String       { t("CANCEL",                    "CANCELAR",                    "ANNULER", "キャンセル") }

    // Countdown
    var matchFound: String         { t("MATCH FOUND",               "RIVAL ENCONTRADO",            "MATCH TROUVÉ", "対戦相手が見つかりました") }
    var secondRace: String         { t("30 SECOND RACE",            "CARRERA DE 30 SEGUNDOS",      "COURSE DE 30 SECONDES", "30秒レース") }
    var generatingBoard: String    { t("GENERATING BOARD...",       "GENERANDO TABLERO...",        "GÉNÉRATION DU PLATEAU...", "ボード生成中...") }
    var versusGo: String           { t("GO!",                       "¡YA!",                        "C'EST PARTI !", "GO!") }
    var versusConnectionTimeout: String { t("CONNECTION TIMEOUT",     "TIEMPO DE CONEXIÓN AGOTADO",  "DÉLAI DE CONNEXION DÉPASSÉ", "接続タイムアウト") }

    // Gameplay HUD
    func tapsCount(_ n: Int) -> String { t("TAPS: \(n)",            "TOQUES: \(n)",                "TAPS : \(n)", "タップ: \(n)") }
    var yourSide: String           { t("YOU",                       "TÚ",                          "VOUS", "あなた") }
    var rivalSide: String          { t("RIVAL",                     "RIVAL",                       "RIVAL", "ライバル") }
    var versusTarget: String       { t("TARGET",                    "OBJETIVO",                    "CIBLE", "ターゲット") }
    var versusMovesLabel: String   { t("MOVES",                     "MOVIMIENTOS",                 "MOUVEMENTS", "手数") }
    var versusRivalHint: String    { t("RIVAL",                     "RIVAL",                       "RIVAL", "ライバル") }
    var versusReachTarget: String  { t("CONNECT TO THE TARGET",     "CONECTA AL OBJETIVO",         "CONNECTEZ À LA CIBLE", "ターゲットに接続せよ") }

    // Result titles
    var victory: String            { t("VICTORY",                   "VICTORIA",                    "VICTOIRE", "勝利") }
    var defeat: String             { t("DEFEAT",                    "DERROTA",                     "DÉFAITE", "敗北") }
    var versusDraw: String         { t("DRAW",                      "EMPATE",                      "MATCH NUL", "引き分け") }
    var opponentDisconnected: String { t("OPPONENT DISCONNECTED",   "RIVAL DESCONECTADO",          "ADVERSAIRE DÉCONNECTÉ", "対戦相手が切断") }
    var connectionLost: String     { t("CONNECTION LOST",           "CONEXIÓN PERDIDA",            "CONNEXION PERDUE", "接続切断") }
    var resolving: String          { t("RESOLVING...",              "RESOLVIENDO...",              "RÉSOLUTION...", "判定中...") }

    // Result reasons
    var reasonConnectedFirst: String { t("SIGNAL CONNECTED FIRST",  "SEÑAL CONECTADA PRIMERO",     "SIGNAL CONNECTÉ EN PREMIER", "先にシグナル接続") }
    var reasonRivalConnected: String { t("RIVAL CONNECTED FIRST",   "EL RIVAL CONECTÓ PRIMERO",    "L'ADVERSAIRE A CONNECTÉ EN PREMIER", "ライバルが先に接続") }
    var reasonMoreProgress: String { t("MORE PROGRESS AT TIMEOUT",  "MÁS PROGRESO AL TERMINAR",   "PLUS DE PROGRESSION AU TEMPS IMPARTI", "タイムアウト時の進行度で上回り") }
    var reasonLessProgress: String { t("RIVAL HAD MORE PROGRESS",   "EL RIVAL TENÍA MÁS PROGRESO", "L'ADVERSAIRE AVAIT PLUS DE PROGRESSION", "ライバルの進行度が上") }
    var reasonEvenProgress: String { t("EQUAL PROGRESS — RARE DRAW", "PROGRESO IGUAL — EMPATE RARO", "PROGRESSION ÉGALE — MATCH NUL RARE", "同進行度 — レアな引き分け") }
    var reasonRivalLeft: String    { t("RIVAL LEFT THE MATCH",      "EL RIVAL ABANDONÓ",           "L'ADVERSAIRE A QUITTÉ", "ライバルが退出") }
    var reasonYouLeft: String      { t("LOST CONNECTION",           "CONEXIÓN PERDIDA",            "CONNEXION PERDUE", "接続が切断されました") }

    // Result badges
    var versusWon: String          { t("WON",                       "GANÓ",                        "GAGNÉ", "勝ち") }
    var versusLost: String         { t("LOST",                      "PERDIÓ",                      "PERDU", "負け") }
    var versusMatchResult: String  { t("MATCH RESULT",              "RESULTADO",                   "RÉSULTAT", "対戦結果") }

    // Result actions
    var versusRematch: String      { t("REMATCH",                   "REVANCHA",                    "REVANCHE", "リマッチ") }
    var waitingForOpponent: String { t("WAITING FOR OPPONENT...",    "ESPERANDO AL RIVAL...",       "EN ATTENTE DE L'ADVERSAIRE...", "対戦相手を待っています...") }
    var backToHome: String         { t("BACK TO HOME",              "VOLVER AL INICIO",            "RETOUR À L'ACCUEIL", "ホームに戻る") }
    func vsLabel(_ name: String) -> String { t("vs \(name)",        "vs \(name)",                  "vs \(name)", "vs \(name)") }

    // Bot difficulty
    var versusBotEasy: String      { t("EASY BOT",                  "BOT FÁCIL",                   "BOT FACILE", "イージーボット") }
    var versusBotMedium: String    { t("MEDIUM BOT",                "BOT MEDIO",                   "BOT MOYEN", "ミディアムボット") }
    var versusBotHard: String      { t("HARD BOT",                  "BOT DIFÍCIL",                 "BOT DIFFICILE", "ハードボット") }
    var versusDifficulty: String   { t("DIFFICULTY",                "DIFICULTAD",                  "DIFFICULTÉ", "難易度") }
    var versusRivalProgress: String { t("RIVAL PROGRESS",           "PROGRESO RIVAL",              "PROGRESSION RIVAL", "ライバル進捗") }
    var versusChooseBot: String    { t("PLAY VS BOT",               "JUGAR VS BOT",                "JOUER VS BOT", "ボットと対戦") }
    var versusBoardSize: String    { t("BOARD SIZE",                "TAMAÑO",                      "TAILLE", "盤面サイズ") }
}
