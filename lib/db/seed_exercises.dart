import 'tables.dart';

/// Muscle/equipment tagging for a seeded exercise. Also used by the schema v3
/// migration to backfill exercises created before those columns existed —
/// matched by name, since ids are generated per install.
typedef ExerciseTags = ({
  List<Muscle> primary,
  List<Muscle> secondary,
  Equipment equipment,
});

typedef SeedExercise = ({
  String name,
  List<Muscle> primaryMuscles,
  List<Muscle> secondaryMuscles,
  Equipment equipment,
  LoggingType loggingType,
  String description,
});

const _s = LoggingType.strengthWeightRepsRir;
const _d = LoggingType.durationOnly;

const seedExercises = <SeedExercise>[
  (name: 'Barbell Bench Press', primaryMuscles: [Muscle.chest], secondaryMuscles: [Muscle.triceps, Muscle.deltsFront], equipment: Equipment.barbell, loggingType: _s, description: 'Flat barbell press. Retract the scapulae and keep the bar path over the mid-chest.'),
  (name: 'Incline Dumbbell Press', primaryMuscles: [Muscle.chest], secondaryMuscles: [Muscle.deltsFront, Muscle.triceps], equipment: Equipment.dumbbell, loggingType: _s, description: 'Press on a 30-45 degree incline to bias the upper chest.'),
  (name: 'Cable Fly', primaryMuscles: [Muscle.chest], secondaryMuscles: [Muscle.deltsFront], equipment: Equipment.cable, loggingType: _s, description: 'Sweeping arc with a slight elbow bend, squeezing at the midline.'),
  (name: 'Overhead Press', primaryMuscles: [Muscle.deltsFront], secondaryMuscles: [Muscle.triceps, Muscle.upperBack], equipment: Equipment.barbell, loggingType: _s, description: 'Standing barbell press from the front rack to lockout overhead.'),
  (name: 'Lateral Raise', primaryMuscles: [Muscle.deltsSide], secondaryMuscles: [], equipment: Equipment.dumbbell, loggingType: _s, description: 'Raise dumbbells to shoulder height, leading with the elbows.'),
  (name: 'Rear Delt Fly', primaryMuscles: [Muscle.deltsRear], secondaryMuscles: [Muscle.upperBack], equipment: Equipment.dumbbell, loggingType: _s, description: 'Bent-over or cable reverse fly for the posterior deltoid.'),
  (name: 'Triceps Pushdown', primaryMuscles: [Muscle.triceps], secondaryMuscles: [], equipment: Equipment.cable, loggingType: _s, description: 'Cable pushdown keeping the elbows pinned to the ribs.'),
  (name: 'Overhead Triceps Extension', primaryMuscles: [Muscle.triceps], secondaryMuscles: [], equipment: Equipment.dumbbell, loggingType: _s, description: 'Stretch the long head of the triceps overhead before extending.'),
  (name: 'Lat Pulldown', primaryMuscles: [Muscle.lats], secondaryMuscles: [Muscle.biceps, Muscle.upperBack], equipment: Equipment.machine, loggingType: _s, description: 'Pull the bar to the upper chest, driving the elbows down and back.'),
  (name: 'Seated Cable Row', primaryMuscles: [Muscle.lats], secondaryMuscles: [Muscle.upperBack, Muscle.biceps], equipment: Equipment.cable, loggingType: _s, description: 'Row to the navel with a neutral spine and controlled eccentric.'),
  (name: 'Barbell Row', primaryMuscles: [Muscle.lats], secondaryMuscles: [Muscle.upperBack, Muscle.biceps, Muscle.lowerBack], equipment: Equipment.barbell, loggingType: _s, description: 'Hinged bent-over row to the lower ribs.'),
  (name: 'Pull-Up', primaryMuscles: [Muscle.lats], secondaryMuscles: [Muscle.biceps, Muscle.upperBack], equipment: Equipment.bodyweight, loggingType: _s, description: 'Bodyweight or weighted pull-up to chin over the bar.'),
  (name: 'Face Pull', primaryMuscles: [Muscle.deltsRear], secondaryMuscles: [Muscle.upperBack], equipment: Equipment.cable, loggingType: _s, description: 'High cable pull to the forehead with external rotation.'),
  (name: 'Barbell Curl', primaryMuscles: [Muscle.biceps], secondaryMuscles: [Muscle.forearms], equipment: Equipment.barbell, loggingType: _s, description: 'Supinated curl with the elbows fixed at the sides.'),
  (name: 'Hammer Curl', primaryMuscles: [Muscle.biceps], secondaryMuscles: [Muscle.forearms], equipment: Equipment.dumbbell, loggingType: _s, description: 'Neutral-grip curl biasing the brachialis and brachioradialis.'),
  (name: 'Back Squat', primaryMuscles: [Muscle.quadriceps], secondaryMuscles: [Muscle.glutes, Muscle.hamstrings, Muscle.lowerBack], equipment: Equipment.barbell, loggingType: _s, description: 'Barbell squat to at least parallel with a braced torso.'),
  (name: 'Front Squat', primaryMuscles: [Muscle.quadriceps], secondaryMuscles: [Muscle.glutes, Muscle.upperBack, Muscle.abs], equipment: Equipment.barbell, loggingType: _s, description: 'Front-racked squat emphasising the quads and upper back.'),
  (name: 'Romanian Deadlift', primaryMuscles: [Muscle.hamstrings], secondaryMuscles: [Muscle.glutes, Muscle.lowerBack], equipment: Equipment.barbell, loggingType: _s, description: 'Hip hinge with soft knees, lowering until the hamstrings stretch.'),
  (name: 'Leg Press', primaryMuscles: [Muscle.quadriceps], secondaryMuscles: [Muscle.glutes, Muscle.hamstrings], equipment: Equipment.machine, loggingType: _s, description: 'Machine press with feet shoulder-width, avoiding lumbar rounding.'),
  (name: 'Leg Curl', primaryMuscles: [Muscle.hamstrings], secondaryMuscles: [Muscle.calves], equipment: Equipment.machine, loggingType: _s, description: 'Seated or lying hamstring curl through a full range.'),
  (name: 'Leg Extension', primaryMuscles: [Muscle.quadriceps], secondaryMuscles: [], equipment: Equipment.machine, loggingType: _s, description: 'Knee extension with a pause at the top.'),
  (name: 'Walking Lunge', primaryMuscles: [Muscle.quadriceps], secondaryMuscles: [Muscle.glutes, Muscle.hamstrings], equipment: Equipment.bodyweight, loggingType: _s, description: 'Alternating forward lunges with an upright torso.'),
  (name: 'Standing Calf Raise', primaryMuscles: [Muscle.calves], secondaryMuscles: [], equipment: Equipment.machine, loggingType: _s, description: 'Full stretch at the bottom, full contraction at the top.'),
  (name: 'Plank', primaryMuscles: [Muscle.abs], secondaryMuscles: [Muscle.obliques, Muscle.glutes], equipment: Equipment.bodyweight, loggingType: _d, description: 'Forearm plank with a neutral spine and braced glutes.'),
  (name: 'Side Plank', primaryMuscles: [Muscle.obliques], secondaryMuscles: [Muscle.abs, Muscle.glutes], equipment: Equipment.bodyweight, loggingType: _d, description: 'Lateral plank stacking shoulder, hip and ankle.'),
  (name: 'Hanging Leg Raise', primaryMuscles: [Muscle.abs], secondaryMuscles: [Muscle.obliques, Muscle.forearms], equipment: Equipment.bodyweight, loggingType: _s, description: 'Raise the legs to hip height or above without swinging.'),
  (name: 'Cable Crunch', primaryMuscles: [Muscle.abs], secondaryMuscles: [Muscle.obliques], equipment: Equipment.cable, loggingType: _s, description: 'Kneeling crunch flexing the spine against cable resistance.'),
  (name: 'Dead Bug', primaryMuscles: [Muscle.abs], secondaryMuscles: [Muscle.obliques], equipment: Equipment.bodyweight, loggingType: _s, description: 'Alternating limb lowering with the lower back pinned down.'),
  (name: 'Hamstring Stretch', primaryMuscles: [Muscle.hamstrings], secondaryMuscles: [], equipment: Equipment.bodyweight, loggingType: _d, description: 'Seated or standing hamstring stretch, held without bouncing.'),
  (name: 'Hip Flexor Stretch', primaryMuscles: [Muscle.hipFlexors], secondaryMuscles: [Muscle.quadriceps], equipment: Equipment.bodyweight, loggingType: _d, description: 'Half-kneeling lunge stretch with a posterior pelvic tilt.'),
  (name: 'Pigeon Stretch', primaryMuscles: [Muscle.glutes], secondaryMuscles: [Muscle.hipFlexors], equipment: Equipment.bodyweight, loggingType: _d, description: 'Glute and external rotator stretch in a pigeon position.'),
  (name: 'Chest Doorway Stretch', primaryMuscles: [Muscle.chest], secondaryMuscles: [Muscle.deltsFront], equipment: Equipment.bodyweight, loggingType: _d, description: 'Pec stretch with the forearm braced against a doorframe.'),
  (name: 'Thoracic Extension', primaryMuscles: [Muscle.upperBack], secondaryMuscles: [], equipment: Equipment.bodyweight, loggingType: _d, description: 'Foam-roller extension over the mid-back.'),
  (name: 'Couch Stretch', primaryMuscles: [Muscle.hipFlexors], secondaryMuscles: [Muscle.quadriceps], equipment: Equipment.bodyweight, loggingType: _d, description: 'Rear-foot-elevated quad and hip flexor stretch.'),
  // ---------------------------------------------------------------------
  // Added 2026-08-23 from the owner's actual routine (Push/Pull/Legs, ab
  // circuit, morning stretch) — movements that were trained but absent from
  // the starter library.
  // ---------------------------------------------------------------------
  (name: 'Incline Barbell Press', primaryMuscles: [Muscle.chest], secondaryMuscles: [Muscle.deltsFront, Muscle.triceps], equipment: Equipment.barbell, loggingType: _s, description: 'Barbell press on a 30-45 degree incline.'),
  (name: 'Flat Dumbbell Bench Press', primaryMuscles: [Muscle.chest], secondaryMuscles: [Muscle.triceps, Muscle.deltsFront], equipment: Equipment.dumbbell, loggingType: _s, description: 'Flat dumbbell press with a full stretch at the bottom.'),
  (name: 'Cable Lateral Raise', primaryMuscles: [Muscle.deltsSide], secondaryMuscles: [], equipment: Equipment.cable, loggingType: _s, description: 'Single-arm cable raise to shoulder height, constant tension throughout.'),
  (name: 'Cable Fly Low to High', primaryMuscles: [Muscle.chest], secondaryMuscles: [Muscle.deltsFront], equipment: Equipment.cable, loggingType: _s, description: 'Low-pulley fly sweeping upward to bias the upper chest.'),
  (name: 'Dips', primaryMuscles: [Muscle.chest], secondaryMuscles: [Muscle.triceps, Muscle.deltsFront], equipment: Equipment.bodyweight, loggingType: _s, description: 'Parallel-bar dip with a slight forward lean for the chest.'),
  (name: 'Single Arm DB Row', primaryMuscles: [Muscle.lats], secondaryMuscles: [Muscle.upperBack, Muscle.biceps], equipment: Equipment.dumbbell, loggingType: _s, description: 'One-arm row braced on a bench, driving the elbow to the hip.'),
  (name: 'Chest Supported DB Row', primaryMuscles: [Muscle.lats], secondaryMuscles: [Muscle.upperBack, Muscle.biceps, Muscle.deltsRear], equipment: Equipment.dumbbell, loggingType: _s, description: 'Row from an incline bench, chest supported to remove momentum.'),
  (name: 'Deadlift', primaryMuscles: [Muscle.hamstrings], secondaryMuscles: [Muscle.glutes, Muscle.lowerBack, Muscle.upperBack, Muscle.forearms], equipment: Equipment.barbell, loggingType: _s, description: 'Conventional deadlift from the floor with a neutral spine.'),
  (name: 'Incline DB Curl', primaryMuscles: [Muscle.biceps], secondaryMuscles: [Muscle.forearms], equipment: Equipment.dumbbell, loggingType: _s, description: 'Curl from an incline bench with the arms behind the torso.'),
  (name: 'Single Arm Cable Curl', primaryMuscles: [Muscle.biceps], secondaryMuscles: [Muscle.forearms], equipment: Equipment.cable, loggingType: _s, description: 'One-arm cable curl with constant tension through the range.'),
  (name: 'Bulgarian Split Squat', primaryMuscles: [Muscle.quadriceps], secondaryMuscles: [Muscle.glutes, Muscle.hamstrings], equipment: Equipment.dumbbell, loggingType: _s, description: 'Rear foot elevated split squat, front shin travelling forward.'),
  (name: 'Leg Raise', primaryMuscles: [Muscle.abs], secondaryMuscles: [Muscle.hipFlexors, Muscle.obliques], equipment: Equipment.bodyweight, loggingType: _s, description: 'Lying leg raise with the lower back pressed into the floor.'),
  (name: 'Bicycle Crunch', primaryMuscles: [Muscle.abs], secondaryMuscles: [Muscle.obliques], equipment: Equipment.bodyweight, loggingType: _s, description: 'Alternating elbow-to-opposite-knee crunch with the legs cycling.'),
  (name: 'Reverse Crunch', primaryMuscles: [Muscle.abs], secondaryMuscles: [Muscle.obliques, Muscle.hipFlexors], equipment: Equipment.bodyweight, loggingType: _s, description: 'Curl the pelvis toward the ribs, lifting the hips off the floor.'),
  (name: 'Mountain Climbers', primaryMuscles: [Muscle.abs], secondaryMuscles: [Muscle.obliques, Muscle.hipFlexors], equipment: Equipment.bodyweight, loggingType: _d, description: 'Plank position, driving the knees alternately toward the chest.'),
  (name: 'Hollow Body Hold', primaryMuscles: [Muscle.abs], secondaryMuscles: [Muscle.obliques, Muscle.hipFlexors], equipment: Equipment.bodyweight, loggingType: _d, description: 'Lower back pinned flat, shoulders and legs held off the floor.'),
  (name: 'Chin Tucks', primaryMuscles: [Muscle.neck], secondaryMuscles: [], equipment: Equipment.bodyweight, loggingType: _d, description: 'Draw the chin straight back over the spine, holding without tilting.'),
  (name: 'Wall Slides', primaryMuscles: [Muscle.upperBack], secondaryMuscles: [Muscle.deltsRear, Muscle.deltsFront], equipment: Equipment.bodyweight, loggingType: _d, description: 'Forearms on the wall, sliding overhead while keeping ribs down.'),
  (name: 'Cat-Cow', primaryMuscles: [Muscle.upperBack], secondaryMuscles: [Muscle.lowerBack, Muscle.abs], equipment: Equipment.bodyweight, loggingType: _d, description: 'Segmental spinal flexion and extension on all fours.'),
  (name: 'Deep Squat Hold', primaryMuscles: [Muscle.hipFlexors], secondaryMuscles: [Muscle.glutes, Muscle.adductors, Muscle.quadriceps], equipment: Equipment.bodyweight, loggingType: _d, description: 'Sit into a deep squat and hold, elbows pressing the knees open.'),
  (name: 'Hip 90/90', primaryMuscles: [Muscle.glutes], secondaryMuscles: [Muscle.hipFlexors, Muscle.adductors], equipment: Equipment.bodyweight, loggingType: _d, description: 'Both knees at 90 degrees, rotating between sides and leaning over the front shin.'),
];

/// Seed tags keyed by lowercased name, for the schema migrations' backfill.
/// Built from [seedExercises] so the two can never drift apart.
final Map<String, ExerciseTags> seedTagsByName = {
  for (final s in seedExercises)
    s.name.toLowerCase(): (
      primary: s.primaryMuscles,
      secondary: s.secondaryMuscles,
      equipment: s.equipment,
    ),
};
