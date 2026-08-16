import 'tables.dart';

typedef SeedExercise = ({
  String name,
  String category,
  LoggingType loggingType,
  String description,
});

const _s = LoggingType.strengthWeightRepsRir;
const _d = LoggingType.durationOnly;

const seedExercises = <SeedExercise>[
  (name: 'Barbell Bench Press', category: 'Chest', loggingType: _s, description: 'Flat barbell press. Retract the scapulae and keep the bar path over the mid-chest.'),
  (name: 'Incline Dumbbell Press', category: 'Chest', loggingType: _s, description: 'Press on a 30-45 degree incline to bias the upper chest.'),
  (name: 'Cable Fly', category: 'Chest', loggingType: _s, description: 'Sweeping arc with a slight elbow bend, squeezing at the midline.'),
  (name: 'Overhead Press', category: 'Shoulders', loggingType: _s, description: 'Standing barbell press from the front rack to lockout overhead.'),
  (name: 'Lateral Raise', category: 'Shoulders', loggingType: _s, description: 'Raise dumbbells to shoulder height, leading with the elbows.'),
  (name: 'Rear Delt Fly', category: 'Shoulders', loggingType: _s, description: 'Bent-over or cable reverse fly for the posterior deltoid.'),
  (name: 'Triceps Pushdown', category: 'Arms', loggingType: _s, description: 'Cable pushdown keeping the elbows pinned to the ribs.'),
  (name: 'Overhead Triceps Extension', category: 'Arms', loggingType: _s, description: 'Stretch the long head of the triceps overhead before extending.'),
  (name: 'Lat Pulldown', category: 'Back', loggingType: _s, description: 'Pull the bar to the upper chest, driving the elbows down and back.'),
  (name: 'Seated Cable Row', category: 'Back', loggingType: _s, description: 'Row to the navel with a neutral spine and controlled eccentric.'),
  (name: 'Barbell Row', category: 'Back', loggingType: _s, description: 'Hinged bent-over row to the lower ribs.'),
  (name: 'Pull-Up', category: 'Back', loggingType: _s, description: 'Bodyweight or weighted pull-up to chin over the bar.'),
  (name: 'Face Pull', category: 'Back', loggingType: _s, description: 'High cable pull to the forehead with external rotation.'),
  (name: 'Barbell Curl', category: 'Arms', loggingType: _s, description: 'Supinated curl with the elbows fixed at the sides.'),
  (name: 'Hammer Curl', category: 'Arms', loggingType: _s, description: 'Neutral-grip curl biasing the brachialis and brachioradialis.'),
  (name: 'Back Squat', category: 'Legs', loggingType: _s, description: 'Barbell squat to at least parallel with a braced torso.'),
  (name: 'Front Squat', category: 'Legs', loggingType: _s, description: 'Front-racked squat emphasising the quads and upper back.'),
  (name: 'Romanian Deadlift', category: 'Legs', loggingType: _s, description: 'Hip hinge with soft knees, lowering until the hamstrings stretch.'),
  (name: 'Leg Press', category: 'Legs', loggingType: _s, description: 'Machine press with feet shoulder-width, avoiding lumbar rounding.'),
  (name: 'Leg Curl', category: 'Legs', loggingType: _s, description: 'Seated or lying hamstring curl through a full range.'),
  (name: 'Leg Extension', category: 'Legs', loggingType: _s, description: 'Knee extension with a pause at the top.'),
  (name: 'Walking Lunge', category: 'Legs', loggingType: _s, description: 'Alternating forward lunges with an upright torso.'),
  (name: 'Standing Calf Raise', category: 'Legs', loggingType: _s, description: 'Full stretch at the bottom, full contraction at the top.'),
  (name: 'Plank', category: 'Core', loggingType: _d, description: 'Forearm plank with a neutral spine and braced glutes.'),
  (name: 'Side Plank', category: 'Core', loggingType: _d, description: 'Lateral plank stacking shoulder, hip and ankle.'),
  (name: 'Hanging Leg Raise', category: 'Core', loggingType: _s, description: 'Raise the legs to hip height or above without swinging.'),
  (name: 'Cable Crunch', category: 'Core', loggingType: _s, description: 'Kneeling crunch flexing the spine against cable resistance.'),
  (name: 'Dead Bug', category: 'Core', loggingType: _s, description: 'Alternating limb lowering with the lower back pinned down.'),
  (name: 'Hamstring Stretch', category: 'Stretching', loggingType: _d, description: 'Seated or standing hamstring stretch, held without bouncing.'),
  (name: 'Hip Flexor Stretch', category: 'Stretching', loggingType: _d, description: 'Half-kneeling lunge stretch with a posterior pelvic tilt.'),
  (name: 'Pigeon Stretch', category: 'Stretching', loggingType: _d, description: 'Glute and external rotator stretch in a pigeon position.'),
  (name: 'Chest Doorway Stretch', category: 'Stretching', loggingType: _d, description: 'Pec stretch with the forearm braced against a doorframe.'),
  (name: 'Thoracic Extension', category: 'Stretching', loggingType: _d, description: 'Foam-roller extension over the mid-back.'),
  (name: 'Couch Stretch', category: 'Stretching', loggingType: _d, description: 'Rear-foot-elevated quad and hip flexor stretch.'),
];
