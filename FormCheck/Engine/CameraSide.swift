/// Which camera films the set. Front is the default: the screen faces the
/// lifter, so the live skeleton, rep counter, and fault banners are actually
/// visible mid-set. Back camera suits a spotter filming or max video quality.
enum CameraSide: String, CaseIterable, Identifiable {
    case front = "Front Camera"
    case back = "Back Camera"

    var id: String { rawValue }
}
