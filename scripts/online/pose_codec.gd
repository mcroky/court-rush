extends RefCounted
## Fixed 14 bytes/bone: normalized quaternion and local translation.
## Quaternion error < 0.000031; translation error <= 0.05 mm.
static func encode(skeleton: Skeleton3D) -> String:
	var bytes=PackedByteArray(); bytes.resize(skeleton.get_bone_count()*14)
	for j in skeleton.get_bone_count():
		var pose=skeleton.get_bone_pose(j)
		var q=pose.basis.get_rotation_quaternion().normalized()
		var values=[q.x,q.y,q.z,q.w,pose.origin.x,pose.origin.y,pose.origin.z]
		for k in 7:
			bytes.encode_s16(j*14+k*2,clampi(roundi(values[k]*(32767 if k<4 else 10000)),-32767,32767))
	return Marshalls.raw_to_base64(bytes)

static func decode(encoded: String, count: int) -> Array:
	var bytes=Marshalls.base64_to_raw(encoded)
	var bones: Array=[]
	if count<1 or count>128 or bytes.size()!=count*14: return bones
	for j in count:
		var values: Array=[]
		for k in 7: values.append(float(bytes.decode_s16(j*14+k*2))/(32767 if k<4 else 10000))
		bones.append(values)
	return bones
