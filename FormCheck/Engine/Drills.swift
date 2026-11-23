import Foundation

/// A concrete, gym-floor fix for each fault: why it matters plus a drill to
/// groove the right pattern. Shown after a set ("Bones' fix") and in history.
struct Drill {
    let title: String
    let why: String
    let steps: [String]
}

extension FormFault {
    var drill: Drill {
        switch self {
        case .shallowDepth:
            return Drill(title: "Box squat to depth",
                         why: "Parallel builds full-range strength and keeps load off the knees' end range.",
                         steps: ["Set a box or bench so your hip crease lands just below your knee",
                                 "Sit back until you touch it — don't plop, just kiss it",
                                 "3 × 8, then try the same depth without the box"])
        case .excessiveLean:
            return Drill(title: "Goblet squat hold",
                         why: "Too much lean turns a squat into a good-morning and loads your lower back.",
                         steps: ["Hold a dumbbell at your chest, elbows inside the knees",
                                 "Squat down and pause 3 seconds at the bottom, chest proud",
                                 "3 × 6 — the weight in front teaches you to stay upright"])
        case .kneeValgus:
            return Drill(title: "Banded knee-out squats",
                         why: "Knees caving under load is the #1 knee-stress pattern in the squat.",
                         steps: ["Loop a light band just above your knees",
                                 "Squat while pushing the band apart the whole way",
                                 "3 × 10, then cue \"knees over pinky toes\" on working sets"])
        case .lateralShift:
            return Drill(title: "Split-stance balance work",
                         why: "Shifting to one side usually means one leg is doing more of the work.",
                         steps: ["Do Bulgarian split squats, weaker side first",
                                 "Match reps on the strong side — never more",
                                 "3 × 8 each leg, film from the front to check"])
        case .uncontrolledDescent:
            return Drill(title: "3-second tempo squats",
                         why: "Dropping fast kills tension and makes the bottom position unstable.",
                         steps: ["Count \"one-thousand-one…three\" on the way down",
                                 "Drive up at normal speed",
                                 "3 × 5 at 60% of your working weight"])
        case .hipsRiseEarly:
            return Drill(title: "Paused deadlift off the floor",
                         why: "Hips shooting up turns the pull into a stiff-leg deadlift and strains the back.",
                         steps: ["Break the bar off the floor and pause 2 s just below the knee",
                                 "Keep your chest and hips rising at the same speed",
                                 "3 × 3 at 60–70%"])
        case .barDrift:
            return Drill(title: "Lat-engaged pulls",
                         why: "Every inch the bar drifts forward multiplies the load on your lower back.",
                         steps: ["Before pulling, \"squeeze oranges in your armpits\"",
                                 "Drag the bar up your shins and thighs — wear long socks",
                                 "3 × 5 with a 2 s pause at the knee"])
        case .incompleteLockout:
            return Drill(title: "Glute-squeeze lockouts",
                         why: "A soft lockout is a rep you didn't finish — and judges won't count it.",
                         steps: ["At the top, squeeze your glutes hard for 1 s",
                                 "Stand tall: shoulders over hips, no hyper-extension",
                                 "Add hip thrusts 3 × 10 to strengthen the finish"])
        case .benchPartialRep:
            return Drill(title: "Paused bench",
                         why: "Full range builds the strength at the bottom where most lifts fail.",
                         steps: ["Lower the bar to your lower chest", "Pause 1 s, motionless", "3 × 5 at 70%"])
        case .barBounce:
            return Drill(title: "Touch-and-hold bench",
                         why: "Bouncing borrows momentum and bruises your sternum.",
                         steps: ["Lower under control", "Touch lightly and hold 1 s", "Press without any sink"])
        case .benchSoftLockout:
            return Drill(title: "Close-grip lockouts",
                         why: "Triceps finish the press — weak lockouts mean weak triceps.",
                         steps: ["Close-grip bench 3 × 8", "Squeeze elbows straight at the top", "Add dips 3 × 10"])
        case .pressNotOverhead:
            return Drill(title: "Head-through presses",
                         why: "The bar should finish stacked over your mid-foot, not in front of you.",
                         steps: ["Press, then push your head \"through the window\" under the bar",
                                 "Lock elbows and shrug up at the top",
                                 "3 × 6 with an empty bar or light dumbbells"])
        case .pressLeanBack:
            return Drill(title: "Hollow-body press",
                         why: "Leaning back turns the press into an incline press and loads your lower back.",
                         steps: ["Squeeze glutes and brace abs like you're about to be punched",
                                 "Ribs down — keep them stacked over your hips",
                                 "Practice 3 × 30 s hollow holds between sets"])
        case .lungeShallow:
            return Drill(title: "Deficit reverse lunges",
                         why: "A full-depth lunge trains the glutes and protects the front knee.",
                         steps: ["Stand on a 5 cm plate, step back off it",
                                 "Lower until your back knee nearly touches the floor",
                                 "3 × 8 each leg, slow on the way down"])
        }
    }
}
