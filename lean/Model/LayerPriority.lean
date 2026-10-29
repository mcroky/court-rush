/-!
Court Rush MotionBricks sequential layer guard and clip handover.
Source: scripts/motionbricks_pose.gd:16-22 reset, 45-77 apply;
scripts/rigged_visual.gd:798-801 reset before sample, 872-873 apply before IK.
Booleans stand for the source float comparisons; clock expiry is evaluated
after selection and delta addition. A fresh clip's expiry input must therefore
use the newly selected duration. Positive weight stands for weight >= .001.
No float arithmetic, quaternion/IK quality, physics, or concurrency is proved.
Source integers are int64; the finite branch/clip logic cannot overflow.
-/
namespace LayerPriority

structure Flags where
  idle : Bool
  grounded : Bool
  defenseLow : Bool
  boxoutLow : Bool
  dribbleOpen : Bool
  noChase : Bool
  noShotRecovery : Bool
deriving Repr, DecidableEq

def eligible (f : Flags) : Bool :=
  f.idle && f.grounded && f.defenseLow && f.boxoutLow &&
  f.dribbleOpen && f.noChase && f.noShotRecovery

def applies (enabled : Bool) (f : Flags) (positiveWeight : Bool) : Bool :=
  enabled && eligible f && positiveWeight

def EligibleProperty (f : Flags) : Prop :=
  f.idle = true ∧ f.grounded = true ∧ f.defenseLow = true ∧
  f.boxoutLow = true ∧ f.dribbleOpen = true ∧ f.noChase = true ∧
  f.noShotRecovery = true

instance (f : Flags) : Decidable (EligibleProperty f) := by
  unfold EligibleProperty
  infer_instance

inductive Clip where
  | run | stopL | stopR | leftL | leftR | rightL | rightR
deriving Repr, DecidableEq, BEq

def clips : List Clip := [.run,.stopL,.stopR,.leftL,.leftR,.rightL,.rightR]

def cutClip (left supportR : Bool) : Clip :=
  if left then (if supportR then .leftR else .leftL)
  else (if supportR then .rightR else .rightL)

def brakeClip (supportR : Bool) : Clip := if supportR then .stopR else .stopL

structure Selection where
  enabled : Bool
  eligible : Bool
  cut : Bool
  braking : Bool
  previousBraking : Bool
  left : Bool
  supportR : Bool
  expired : Bool
  old : Clip
deriving Repr, DecidableEq

def selectClip (s : Selection) : Clip :=
  if !s.enabled then s.old else
  let chosen :=
    if s.eligible && s.cut then cutClip s.left s.supportR
    else if s.eligible && s.braking && !s.previousBraking then brakeClip s.supportR
    else s.old
  if chosen != .run && s.expired then .run else chosen

-- Independent expected table puts final expiry before trigger priorities.
def ExpectedSelection (s : Selection) (result : Clip) : Prop :=
  if s.enabled = false then result = s.old
  else if s.expired = true then result = .run
  else if s.eligible = true ∧ s.cut = true then
    match s.left,s.supportR with
    | true,true => result = .leftR
    | true,false => result = .leftL
    | false,true => result = .rightR
    | false,false => result = .rightL
  else if s.eligible = true ∧ s.braking = true ∧ s.previousBraking = false then
    if s.supportR = true then result = .stopR else result = .stopL
  else result = s.old

instance (s : Selection) (c : Clip) : Decidable (ExpectedSelection s c) := by
  unfold ExpectedSelection
  split
  · infer_instance
  · split
    · infer_instance
    · split
      · cases s.left <;> cases s.supportR <;> infer_instance
      · split
        · split <;> infer_instance
        · infer_instance

structure State where
  active : Clip
  weightNonzero : Bool
  clock : Nat
  previousRedirectNonzero : Bool
  previousBraking : Bool
  offsetsClear : Bool
deriving Repr, DecidableEq

def reset (_ : State) : State := ⟨.run,false,0,false,false,true⟩

def bit (mask index : Nat) : Bool := mask / (2^index) % 2 == 1
def flags (mask : Nat) : Flags :=
  ⟨bit mask 0,bit mask 1,bit mask 2,bit mask 3,bit mask 4,bit mask 5,bit mask 6⟩

def guardResults : List Bool := (List.range 256).map fun mask => applies (bit mask 7) (flags mask) true
def badGuards : List Nat := (List.range 256).filter fun mask =>
  applies (bit mask 7) (flags mask) true != (mask == 255)

def selections : List Selection :=
  (List.range 256).flatMap fun mask => clips.map fun old =>
    ⟨bit mask 0,bit mask 1,bit mask 2,bit mask 3,bit mask 4,
      bit mask 5,bit mask 6,bit mask 7,old⟩

def badSelections : List Selection := selections.filter fun s => !decide (ExpectedSelection s (selectClip s))

#eval (badGuards.length,badSelections.length)
#guard badGuards.isEmpty
#guard badSelections.isEmpty
#guard (guardResults.filter id).length = 1
#guard selections.any fun s => s.enabled && s.eligible && s.cut && s.braking && !s.expired && selectClip s == .leftR
#guard selections.any fun s => s.enabled && s.eligible && s.cut && s.braking && s.expired && selectClip s == .run

theorem applies_iff (enabled positiveWeight : Bool) (f : Flags) :
    applies enabled f positiveWeight = true ↔ enabled = true ∧ EligibleProperty f ∧ positiveWeight = true := by
  simp [applies,eligible,EligibleProperty,and_assoc]

theorem excluded_never_applies (enabled positiveWeight : Bool) (f : Flags)
    (excluded : ¬ EligibleProperty f) : applies enabled f positiveWeight = false := by
  cases h : applies enabled f positiveWeight with
  | false => rfl
  | true => exact False.elim (excluded ((applies_iff enabled positiveWeight f).mp h).2.1)

theorem selection_matches (s : Selection) : ExpectedSelection s (selectClip s) := by
  cases s with
  | mk enabled eligible cut braking previousBraking left supportR expired old =>
    cases enabled <;> cases eligible <;> cases cut <;> cases braking <;>
      cases previousBraking <;> cases left <;> cases supportR <;>
      cases expired <;> cases old <;> decide

theorem reset_clears (s : State) : reset s = ⟨.run,false,0,false,false,true⟩ := by
  rfl

#guard reset ⟨.rightR,true,99,true,true,false⟩ = ⟨.run,false,0,false,false,true⟩

#eval "GATE_BITSET " ++ String.ofList (guardResults.map fun b => if b then '1' else '0')
#eval do
  for left in [true,false] do
    for supportR in [true,false] do
      let s : Selection := ⟨true,true,true,true,false,left,supportR,false,.stopL⟩
      IO.println s!"CUT_VECTOR left={left} supportR={supportR} clip={repr (selectClip s)}"
      IO.println s!"EXPIRE_VECTOR left={left} supportR={supportR} clip={repr (selectClip {s with expired := true})}"
#eval s!"RESET_VECTOR {repr (reset ⟨.rightR,true,99,true,true,false⟩)}"

end LayerPriority
