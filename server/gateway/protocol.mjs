export const PROTOCOL = 1;
export const RULES = 'duel-standard-v1';
export const ACTIONS = ['shoot', 'cross', 'spin', 'twostep', 'behind', 'hesi', 'steal', 'guard'];
export function parseInput(message, lastSequence) {
  if (!Number.isSafeInteger(message.seq) || message.seq < 0 || message.seq <= lastSequence || message.seq - lastSequence > 10000) throw Error('input_sequence');
  if (!Number.isFinite(message.x) || !Number.isFinite(message.z) || Math.abs(message.x) > 1 || Math.abs(message.z) > 1) throw Error('input_range');
  const input = { seq: message.seq, x: message.x, z: message.z };
  for (const key of [...ACTIONS, 'shoot_pressed']) {
    if (typeof message[key] !== 'boolean') throw Error('input_type');
    input[key] = message[key];
  }
  const length = Math.hypot(input.x, input.z);
  if (length > 1) { input.x /= length; input.z /= length; }
  return input;
}
export function publicParticipant(member, slot) {
  return { slot, team: slot, nickname: member.nickname, appearance: member.appearance };
}
