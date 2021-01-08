extends TileMap

const COLLIDER_PATH = "res://Tilesets/Collisions/"
const TILE_SIZE = Vector2( 32 , 32 )

onready var staticBody : StaticBody2D = $StaticBody2D

var myCollisions : Array
var tileColliderData = {
	"PatternedOneWayFloor" : {
		"colliderFileName" : COLLIDER_PATH + "6x1.tres" , 
		"offset": Vector2( 0 , 0 )
	}
} 

func _ready():
	pass
	#addSpecialColliders()

func addSpecialColliders() -> void:
	
	var myCells : Array = get_used_cells()
	var myTiles : TileSet = get_tileset()
	
	for key in myCells:
		var thisCellID : int = get_cell( key.x , key.y )
		var thisCellName : String = myTiles.tile_get_name( thisCellID )

		if( tileColliderData.has( thisCellName ) ):
			var colliderData = tileColliderData[thisCellName]
			
			var shape : Shape2D = load( colliderData.colliderFileName )
			var collision : CollisionShape2D = CollisionShape2D.new()

			print( get_cell_autotile_coord( key.x , key.y ) )

			collision.set_shape( shape )
			collision.set_position(  get_cell_autotile_coord( key.x , key.y ) )

			staticBody.add_child( collision )
			print(collision)

			




