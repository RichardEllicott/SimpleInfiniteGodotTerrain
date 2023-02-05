"""

"Richard's Simple Infinite Terrain"

mescalin@gmail.com

liscense: MIT, CC0 or public domain



# What this code does:
    
this code takes a heightmap image and couple of textures which it turns into terrain
    -- the terrain is draw using a custom viual shader (for easy editing)
    -- a HeightMapShape is built from the image to match the shader


# Why did i make this code:

-Zylann's heightmap plugin is great but very complicated. It requires a special custom texture format that i found prone to dataloss.

-My module has no UI or texture painting etc, you must generate all the maps outside but now they're done they're done

-You can keep your workflow as png's therefore and not worry about loosing anything

-because i use a visual shader, it's very easy to edit the fragment part of the shader and leave the vertex part alone



Steps to get going (from scratch):
    
* put this script on a spatial in your scene
    
* set the heigtmap texture as an image, make sure this image is imported as a 3D texture uncompressed (wuth repeat enabled)
-- for best results, use a reasonable size of heightmap image, 256x256 + is reccomended
-- if using larger maps like 1024x1024, set the "visual_mesh_div" and "collision_mesh_div" values higher for a more detailed mesh
-- WARNING: not all features work properly with the NoiseTexture as I cannot get the height values! Here is a quick noise generator that will work:
-- http://kitfox.com/projects/perlinNoiseMaker/
    

* set the shader_material to a new ShaderMaterial, set the materials "shader" par as the included shader "heightmap_visualshader_basic2.tres"
-- the shader has special parameters that match up so you cannot use any shader
-- the shader is a visual shader which is extremely easy to edit including a couple of custom code expressions to work out world coordinates and vertex
-- the shader includes solutions for texture based on world position (similar to triplanar but just projected down)
-- if in doubt just edit the fragment shader parts and leave alone the vertex parts
-- if you edit the code be careful of global variables that are exploited for performance reasons

* ensure the texture has albdeo, normal and roughness  paramaters set... this is important to actually see the light hit the terrain

* the UV_scale of the shader must also be set to a low value (0.125,0.125,0.125) etc

* click the "trigger macro" bool in the editor, this will automaticly set up the terrain as a demo, it should create 3 child nodes:
    - MeshInstance (the visual mesh)
    - StaticBody (matching collision body)
    - MultiMeshInstance (a demo placing cubes on the terrain)



EXTRA FEATURES:

* Infinite Terrain Illusion:
    
    - set "follow_target" to true, set the "target" to a Spatial (ideally the camera), the visual part of the terrain will now follow the camera
    - NOTE: the collision mesh doesn't follow so the player will fall off the map outside the main area still
    
    - one example usage is you could wall the player in but he cannot see just an edge to the map
    - you could even silently teleport the player and since the terrain repeats hide this from the player
    - you could move matching CollisionShapes about, even get more clever and sleep physics/AI at a distance
    
    - it is intentional i leave this code at this point because making a streaming engine like Skyrim involves many arbitary decisions yet this code is easy to modify




NOTES:
    -z is north (upwards on the image), this makes +x east
    ... most of my software uses the -z is north standard it lines up with 2D in the sense that -y is North (up) in 2D +x is East (right)



"""
tool
extends Spatial



enum Macro {
    autosetup, # default setup
    macro02,
   }

export(Macro) var macro = 0

export var trigger_macro = false setget set_trigger_macro
func set_trigger_macro(input):
    if input:
        trigger_macro = false
        _ready() # ensure vars are available
        run_macro(macro)

func run_macro(macro):
    var function_name = Macro.keys()[macro]
    print("print call function: %s" % function_name)
    call(function_name)
    
    







static func grid_snap(position: Vector3, grid_size: Vector3 = Vector3(32,32,32)) -> Vector3:
    """
    snap a Vector3 to a grid position, used to move the terrain about in steps
    
    """
    position /= grid_size
    position = position.floor() # remove the fraction
    position *= grid_size
    position -= grid_size / 2.0 # correction offset to make the snap center
    return position




var active = true # disable to stop following target

func _process(delta):
    
    if active:
        
        
        if follow_target:
            
            if is_instance_valid(get_target()):
                var mesh_instance = get_node_or_null("MeshInstance")
                if is_instance_valid(mesh_instance):
                    var snap_pos = grid_snap(get_target().transform.origin, Vector3(follow_snap,follow_snap,follow_snap))
                    snap_pos.y = 0.0
                    mesh_instance.transform.origin = snap_pos
            
   
func _ready():
    pass




export var terrain_size: Vector3 = Vector3(512,32.0,512) # the terrain size, default 512x512 units and 32 units high (y)
export var offset = Vector3(0.5,0.0,0.5) # default offset of 0.5 puts the image in the center, i have tried tweaking this to about Vector3(0.493,0,0.495) to line up better, i don't think it works

export var visual_mesh_div: Vector2 = Vector2(128,128) # amount of squares, large values can get slow
export var collision_mesh_div: Vector2 = Vector2(128,128) # amount of squares, large values can get extremly slow (physics)


## FOLLOW TARGET

export(NodePath) var _target # normally set to camera, must be set to a Spatial
var target: Spatial
func get_target():
    if not is_instance_valid(target):
        target = get_node(_target) # warning will crash if no target
    return target
    
export var follow_target = false # if true, follow the target around with the visual mesh (creating the illusion of infinite terrain)

export var follow_snap: float = 32.0 # set small enough to be out of range but must be large enough to hide the mesh movement (verts will line up)






export var build_visual_mesh: bool = true # build a visual mesh where our shader uses a heightmap to show terrain
export var build_static_mesh: bool = true # build a matching static body collider

export var build_multimesh_demo: bool = true # scatter some multimesh boxes about the surface to demo how we would place trees
export var multimesh_demo_instance_count: int = 400

var place_csg_box_test = false # a test for checking the coordinate system works correct


#export var adjust_visual_mesh_pos = Vector3(1,0,1) # literally just moves visual mesh transform (pointless now?)


export (Texture) var heightmap_texture : Texture
    
export (ShaderMaterial) var shader_material


static func get_or_create_child(parent: Node,node_name: String, node_type = Node) -> Node:        
    var node = parent.get_node_or_null(node_name) # get the node if present
    if not is_instance_valid(node): # if no node found make one
        node = node_type.new()
        node.name = node_name
        parent.add_child(node)
        if Engine.is_editor_hint():
            node.set_owner(parent.get_tree().edited_scene_root) # show in tool mode
    assert(node is node_type) # best to check the type matches
    return node
        
        





func is_bit_set(value, bit):
    return value & (1 << bit) != 0
    
    
    

func autosetup():
    
    transform = Transform()
    

    if build_visual_mesh:
        
        var mesh_instance: MeshInstance = get_or_create_child(self,"MeshInstance",MeshInstance)
            
        var plane_mesh : PlaneMesh = PlaneMesh.new()
        plane_mesh.size = Vector2(terrain_size.x,terrain_size.z)
        plane_mesh.subdivide_width = visual_mesh_div.x - 1 # we use 1 less as subdiv 7 would give 8 squares (which is 9 verts)
        plane_mesh.subdivide_depth = visual_mesh_div.y - 1
        
        plane_mesh.material = shader_material
        
        if heightmap_texture.get_data().is_compressed(): # textures must be uncompressed (we might be able to decompress later??)
            push_error("texture is compressed, reimport it with compress mode set to \"uncompressed\" (best to use 3D with repeat enabled) ")
            assert(false)
                        
#        # Texture.FLAG_REPEAT #### DOES NOT WORK   .... I WANTED TO DETECT TEXTURE REPEAT FLAG
#        if is_bit_set(heightmap_texture.get_flags(), 2):
#            push_warning("this texture is does not have the repeat flag set to true, it is reccomended to import heightmaps with repeat enabled (use preset 3D and uncompressed)")
#            pass
        
        shader_material.set_shader_param("terrain_scale", terrain_size) # set terrain dimensions including height    
        shader_material.set_shader_param("heightmap_texture", heightmap_texture)
        shader_material.set_shader_param("offset", offset) # normally offset (0.5,0,0.5) to center the map

        mesh_instance.mesh = plane_mesh
        
    if build_static_mesh: # build collision mesh

        var staticbody: StaticBody = get_or_create_child(self,"StaticBody",StaticBody)
        var shape: CollisionShape = get_or_create_child(staticbody,"CollisionShape",CollisionShape)
        
        shape.shape = HeightMapShape.new() 
        build_heightmapshape(shape) # call our build function that loads from an image
        

        
    if build_multimesh_demo: # demo placing items on terrain surface, servers to confirm get_height_at_world_coor function is working
        
        var multimesh_instance = get_node_or_null("MultiMeshInstance")
        
        if not multimesh_instance: # if no multimesh child, build one
            multimesh_instance = get_or_create_child(self,"MultiMeshInstance",MultiMeshInstance)
            var multimesh: MultiMesh = MultiMesh.new()
            multimesh.transform_format = MultiMesh.TRANSFORM_3D
            multimesh_instance.multimesh = multimesh
            var mesh: CubeMesh = CubeMesh.new()
            mesh.size = Vector3(1,1,1) * 4.0
            multimesh.mesh = mesh
            var mat: SpatialMaterial = SpatialMaterial.new()
            mat.albedo_color = Color.red
            mat.flags_unshaded = true # unsahder to stand out
            mesh.material = mat

        multimesh_instance.multimesh.instance_count = multimesh_demo_instance_count
        multimesh_instance.transform = Transform()
        
        var rang: RandomNumberGenerator = RandomNumberGenerator.new()
        
        for i in multimesh_demo_instance_count:
            
            var trans = Transform()
            
            var ran_pos: Vector3 = Vector3(rang.randf()*2.0-1.0,0,rang.randf()*2.0-1.0) # pos between Vector3(-1,0,-1) and Vector3(1,0,1)
            ran_pos *= terrain_size / 2.0 # stretch to terrain size
            ran_pos = get_height_at_world_coor(ran_pos) # get height at world pos
            trans.origin = ran_pos
            multimesh_instance.multimesh.set_instance_transform(i, trans)

            
    # simple test shows placing a box on the terrain at coordinates (should detect the terrain height)
    
    if place_csg_box_test:
        var csg_box: CSGBox = get_or_create_child(self,"CSGBox",CSGBox)
        csg_box.transform.origin = get_height_at_world_coor(Vector3(-128,0,-128))




## UNUSED.... so far using image...BETTER TO USE IMAGE?
func get_heightmap_height(heightmap : HeightMapShape, x : float, y : float):
    assert(false)
    var ref = y * heightmap.map_width + x

    var cell = heightmap.map_data[ref]
    return cell
    




func get_height_at_world_coor(world_coor: Vector3) -> Vector3:
    """
    get the map height at a world position (note the world positions extend into negative)
    for a 512x map, we expect the world to extend 256 units positive and negative
    
    i'm not 100% sure why this lines up with the 256x map, hence div by 256, offset by 128
    """
    
    # the result we get back by default lines up with the 256x map
    
    var new_coor = world_coor # this is just a check coor
    
    new_coor.x /= terrain_size.x / 256.0 # scale relative to world
    new_coor.z /= terrain_size.z / 256.0
    
    new_coor.x -= 128 # then offset (works at all sizes, set for 128!)
    new_coor.z -= 128
    
    world_coor.y = get_height_at_coor(new_coor.x,new_coor.z)

    return world_coor




var _heightmap_imgage: Image # if we query the height, we will save a cache of the image for querying

# get height at coordinates between (0,0) and (1,1)
func get_height_at_coor(x: float, y : float) -> float:

    var pos = Vector2(x,y)
    
    if not _heightmap_imgage:
        _heightmap_imgage = heightmap_texture.get_data()
        _heightmap_imgage.lock() # note i don't need to unlock for editing

    var image_size = _heightmap_imgage.get_size()

    var pix = get_image_interpolated(_heightmap_imgage, x / image_size.x, y / image_size.y)

    var height = pix.r * terrain_size.y

    return float(height)



# static function to return interpolated color value for coordinates from (0,0) to (1,1)
static func get_image_interpolated(heightmap_imgage: Image, x : float, y : float) -> Color:
    """
    
    DESIGN NOTE:
        this function works but ideally i would have liked to sample the texture through the Texture not the Image
    
    
    capable of getting between the pixels for reading heightmaps
    basic bilinear filter that samples 4 pixels and gets an average (biased to which pixel it's nearest to')
    
    built and tested working on 14/07/2022
    

    note image already locked when it goes in here (i think)
    
    
    the input coor are from 0 to 1
    this might not line up correctly... we may try adding modulo to this later or replacing with something built in
    

    """
    
    # these lines ensure the x and y are numbers wrapped into 0->1
    x = fmod(x+1024.0,1.0)
    y = fmod(y+1024.0,1.0)
    
    var image_size = heightmap_imgage.get_size()
#    print("image_size: ", image_size)
    
    x *= image_size.x
    y *= image_size.y
    
    x -= 0.5
    y -= 0.5
    
    var img_size_x = int(image_size.x)
    var img_size_y = int(image_size.y)

    var xi = int(x)# + img_size_x
    var yi = int(y)# + img_size_y
    
    var x_pos = x - xi
    var y_pos = y - yi
    
    var pix1 = heightmap_imgage.get_pixel(
            fmod(xi,img_size_x), 
            fmod(yi,img_size_y))
    
    var pix2 = heightmap_imgage.get_pixel(
        fmod(xi+1,img_size_x), 
        fmod(yi,img_size_y))
        
    var pix3 = heightmap_imgage.get_pixel(
        fmod(xi,img_size_x), 
        fmod(yi+1,img_size_y))
        
    var pix4 = heightmap_imgage.get_pixel(
        fmod(xi+1,img_size_x), 
        fmod(yi+1,img_size_y))

    var col1 = lerp(pix1,pix2,x_pos)
    var col2 = lerp(pix3,pix4,x_pos)
    
    var col12 = lerp(col1,col2,y_pos)
                
    return col12

            

func build_heightmapshape(col_shape : CollisionShape):
    """
    
    builds a heightmap shape to match our shader
    
    this code is manually lined up with the shader and the best i have managed so far, it doesn't 100% line up which is still a slight issue
    
    the problem is far less apparent when there is less detail but i'm still looking if this code can be improved
    
    
    this is likely due to many complications including:
    
    
    an image is usually an even number of squares accross like say for example 16
    a heightmap has +1 nodes accross, so a 8x8 square map has 9x9 verts
    
    
    
    this code actually is tasked with taking an image (which is like a 2D array) and wrapping that data into a (1D) PoolRealArray of height values
        
    """
    
    
    var map_size = Vector2(terrain_size.x,terrain_size.z)  # actual world dimensions of map
    
    var map_width = int(collision_mesh_div.x) + 1 # map width in squares points (one more than squares, which should be even)
    var map_depth = int(collision_mesh_div.y) + 1

    col_shape.scale = Vector3(map_size.x / collision_mesh_div.x, 1, map_size.y / collision_mesh_div.y) # scale by the size divided by divisions

    
    
    var heightmap : HeightMapShape = col_shape.shape
    
    heightmap.map_width = map_width
    heightmap.map_depth = map_depth

    
    
    var heightmap_img: Image = heightmap_texture.get_data()
    
    
    var new_array : PoolRealArray = PoolRealArray()
    new_array.resize(map_depth * map_width)
    
    heightmap_img.lock()
    
    var image_size = heightmap_img.get_size()
    
    var _scale = Vector2(image_size.x / map_width, image_size.y / map_depth)
    
    for y in map_depth:
        for x in map_width:
            
            var ref = y * map_width + x
            
            var pos = Vector2(x,y) * _scale
            
#            var pix = heightmap_img.get_pixel(
#                int(pos.x) % int(image_size.x),
#                int(pos.y) % int(image_size.y))
            
            
            # works?? this was orginal 
            var pix = get_image_interpolated(heightmap_img,pos.x/image_size.x,pos.y/image_size.y)

            # trying to solve logic, this one offset more? less accurate?
#            var pix = get_image_interpolated(heightmap_img, float(y) / map_depth, float(x) / map_width)
            
            var height = pix.r * terrain_size.y

            new_array.set(ref, height)
            
#            print("%s" % [height])
            

    
    heightmap_img.unlock()
    
    heightmap.map_data = new_array
    
    
    
                
