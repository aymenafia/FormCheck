/// Which way the phone faces the lifter. Each view can see different faults:
/// side = depth, lean, tempo; front = knee valgus, lateral shift, tempo.
enum ViewMode: String, CaseIterable, Identifiable {
    case side = "Side"
    case front = "Front"

    var id: String { rawValue }
}
