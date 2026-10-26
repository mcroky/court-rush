extends SceneTree
var failures=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func geometry(parent: Node3D) -> Dictionary:
 var result={}
 for item in parent.find_children("*","MeshInstance3D",true,false):
  var transform=parent.global_transform.affine_inverse()*item.global_transform
  for surface in item.mesh.get_surface_count():
   var mat=item.get_active_material(surface);var arrays=item.mesh.surface_get_arrays(surface)
   var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uvs=arrays[Mesh.ARRAY_TEX_UV]
   var count=indices.size() if indices!=null and indices.size()>0 else vertices.size()
   for i in count:
    var index=indices[i] if indices!=null and indices.size()>0 else i
    var point=transform*vertices[index]
    var normal=(transform.basis.inverse().transposed()*normals[index]).normalized()
    var uv=uvs[index] if uvs!=null and uvs.size()>0 else Vector2.ZERO
    var key=str(mat.get_instance_id())+":"+str(item.cast_shadow)+":"+str((point*1000).round())+":"+str((uv*1000).round())
    if not result.has(key):result[key]=[]
    result[key].append([point,normal,uv])
 return result
func run():
 var art=load("res://scripts/art.gd")
 var world=Node3D.new();root.add_child(world);world.rotation.y=.3
 art.box(world,Vector3(1,2,3),Vector3(1,2,3),"bc8855")
 var rod=art.cylinder(world,Vector3(-2,1,1),.2,.2,1,"bc8855");rod.rotation.z=.6;rod.scale=Vector3(1,2,.6)
 art.box(world,Vector3(0,1,-1),Vector3(.6,.7,.8),"f0e7cf",true)
 var label=art.label(world,"PRESERVE",Vector3(0,3,0),12,"ffffff")
 var before=geometry(world);art.batch_static(world);var after=geometry(world)
 var max_normal_error=0.0
 check(before.size()==after.size(),"Static merge changed material/shadow/vertex/UV groups")
 for key in before:
  check(after.has(key),"Static merge lost a vertex/material/UV group")
  if not after.has(key):continue
  var candidates=after[key].duplicate()
  check(candidates.size()==before[key].size(),"Static merge changed triangle multiplicity")
  for expected in before[key]:
   var best=-1;var error=10.0
   for i in candidates.size():
    var candidate=candidates[i]
    if candidate[0].distance_to(expected[0])<.00002 and candidate[2].distance_to(expected[2])<.00002:
     var normal_error=candidate[1].distance_to(expected[1])
     if normal_error<error:best=i;error=normal_error
   # ArrayMesh packs normals; compare numerical error, not rounded string equality.
   max_normal_error=maxf(max_normal_error,error)
   check(best>=0 and error<.0002,"Static merge changed geometry or normal beyond ArrayMesh packing precision")
   if best>=0:candidates.remove_at(best)
 print("BATCH_NORMAL_MAX_ERROR ",max_normal_error)
 check(is_instance_valid(label) and label.get_parent()==world,"Static batching removed a non-mesh label")
 check(world.find_children("*","MeshInstance3D",true,false).size()==3,"Same material geometry did not share a draw")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 var court=game.get_node("StaticCourt")
 check(court.find_children("*","MeshInstance3D",true,false).size()<45,"Court still has hundreds of render meshes")
 check(game.ball.find_children("*","MeshInstance3D",true,false).size()<6,"Basketball seams still issue individual draws")
 print("STATIC_BATCH keyed_vertices=",before.size()," court_meshes=",court.find_children("*","MeshInstance3D",true,false).size()," ball_meshes=",game.ball.find_children("*","MeshInstance3D",true,false).size()," failures=",failures)
 game.queue_free();world.queue_free();await process_frame;quit(1 if failures else 0)
