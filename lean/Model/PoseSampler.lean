/-!
Source: scripts/motionbricks_pose.gd:31-43 and
tools/bake_motionbricks_bank.gd:14-18, revision 6fe88bb.
The pack has frames * joints * 4 float32 elements. Source indices are signed
64-bit; Nat models their nonnegative range under the assumption that this
small asset (26 frames, 45 joints) cannot overflow int64. We assume clamp and
int(cursor) produced first < frames, and channel < joints. Float clamp,
quaternion normalization/slerp, and visual quality are outside this proof.
-/
namespace PoseSampler

def nextFrame (frames first : Nat) : Nat := min (first + 1) (frames - 1)

def quaternionIndex (joints frame channel : Nat) : Nat :=
  frame * (joints * 4) + channel * 4

def SampleSafe (frames joints first channel : Nat) : Prop :=
  nextFrame frames first < frames ∧
  quaternionIndex joints first channel + 3 < frames * (joints * 4) ∧
  quaternionIndex joints (nextFrame frames first) channel + 3 < frames * (joints * 4)

instance (frames joints first channel : Nat) : Decidable (SampleSafe frames joints first channel) := by
  unfold SampleSafe
  infer_instance

def inputs (frameBound jointBound : Nat) : List (Nat × Nat × Nat × Nat) :=
  (List.range frameBound).flatMap fun f =>
    (List.range jointBound).flatMap fun j =>
      (List.range (f + 1)).flatMap fun first =>
        (List.range (j + 1)).map fun channel => (f + 1, j + 1, first, channel)

def badInputs (frameBound jointBound : Nat) : List (Nat × Nat × Nat × Nat) :=
  (inputs frameBound jointBound).filter fun (f,j,a,c) => !decide (SampleSafe f j a c)

set_option maxRecDepth 4096 in
set_option maxHeartbeats 0 in
#eval (badInputs 27 46).take 3
set_option maxRecDepth 4096 in
set_option maxHeartbeats 0 in
#guard (badInputs 27 46).isEmpty

-- Explicitly require the search to contain the last frame and last channel,
-- including the one-frame boundary. A vacuous search must not pass.
#guard (inputs 27 46).contains (26,45,25,44)
#guard (inputs 27 46).contains (1,1,0,0)
#guard (inputs 27 46).contains (27,46,26,45)

theorem nextFrame_lt (frames first : Nat) (hf : 0 < frames) :
    nextFrame frames first < frames := by
  unfold nextFrame
  have h := Nat.min_le_right (first + 1) (frames - 1)
  omega

theorem quaternionIndex_bound (frames joints frame channel : Nat)
    (hf : frame < frames) (hc : channel < joints) :
    quaternionIndex joints frame channel + 3 < frames * (joints * 4) := by
  have hchannel : channel * 4 + 3 < joints * 4 := by omega
  have hframe : frame + 1 ≤ frames := by omega
  calc
    quaternionIndex joints frame channel + 3
        = frame * (joints * 4) + (channel * 4 + 3) := by simp [quaternionIndex, Nat.add_assoc]
    _ < frame * (joints * 4) + joints * 4 := Nat.add_lt_add_left hchannel _
    _ = (frame + 1) * (joints * 4) := by simp [Nat.add_mul]
    _ ≤ frames * (joints * 4) := Nat.mul_le_mul_right _ hframe

theorem sampleSafe (frames joints first channel : Nat)
    (hframes : 0 < frames) (hfirst : first < frames) (hchannel : channel < joints) :
    SampleSafe frames joints first channel := by
  exact ⟨nextFrame_lt frames first hframes,
    quaternionIndex_bound frames joints first channel hfirst hchannel,
    quaternionIndex_bound frames joints (nextFrame frames first) channel
      (nextFrame_lt frames first hframes) hchannel⟩

def vectors : List (Nat × Nat × Nat × Nat) :=
  [(1,1,0,0),(2,2,0,0),(2,2,1,1),
   (26,45,0,0),(26,45,0,22),(26,45,0,44),
   (26,45,12,0),(26,45,12,22),(26,45,12,44),
   (26,45,25,0),(26,45,25,22),(26,45,25,44)]

#eval do
  for (f,j,a,c) in vectors do
    IO.println s!"SAMPLER_VECTOR {f} {j} {a} {c} {nextFrame f a} {quaternionIndex j a c} {quaternionIndex j (nextFrame f a) c}"

end PoseSampler
