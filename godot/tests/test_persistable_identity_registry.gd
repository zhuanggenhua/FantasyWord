extends SceneTree
const Registry = preload("res://game_core/persistence/persistable_identity_registry.gd")
const Entry = preload("res://gameplay/clickmovetest/entry.tscn")
const Player = preload("res://gameplay/clickmovetest/single_player_actor.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",description)


func run() -> void:
	var scene: Node = Entry.instantiate()
	root.add_child(scene)
	var player := Player.new()
	var registry := Registry.new()
	var actor: Node = scene.actor
	check(player.configure(actor) and registry.register_pre_instanced(actor,Player.SOURCE_PREINSTANCED_IDENTIFIER,false)
		and registry.resolve(Player.SOURCE_PREINSTANCED_IDENTIFIER)==actor,"actual scene player enters with authored UUID")
	player.set_accepts_player_input(false)
	check(not player.register_primary_persistence(registry) and registry.resolve(Player.SOURCE_PREINSTANCED_IDENTIFIER)==actor,
		"startup gate rejects disabled input before custom handler replacement")
	player.set_accepts_player_input(true)
	player.set_current_controlled(false)
	check(player.register_primary_persistence(registry) and player.is_current_controlled(actor),
		"runtime owner resets control to loaded actual player before registration")
	check(registry.resolve(Player.UNIQUE_PLAYER_IDENTIFIER)==actor and registry.identifier_for(actor)=="player"
		and registry.resolve(Player.SOURCE_PREINSTANCED_IDENTIFIER)==null and not registry.automatically_persisted(actor),
		"only custom player ID resolves, not the original UUID or generic automatic save")
	player.set_accepts_player_input(false)
	player.set_current_controlled(false)
	check(registry.resolve("player")==actor,"temporary input loss doesn't unregister the world actor")
	scene.free()
	check(registry.resolve("player")==null,"actor exit unregisters primary identity")

	var aliases := Registry.new({"old":"intermediate","intermediate":"new"})
	var predecessor := Node2D.new()
	var winner := Node2D.new()
	root.add_child(predecessor)
	root.add_child(winner)
	check(not aliases.register_custom_instanced(predecessor," \t ") and aliases.resolve(" \t ")==null,
		"blank explicit identifier is rejected")
	check(aliases.register_pre_instanced(predecessor,"old",true)
		and aliases.automatically_persisted(predecessor)
		and aliases.identifier_for(predecessor)=="old"
		and aliases.resolve("old")==predecessor and aliases.resolve("intermediate")==null,
		"pre-instanced auto flag and raw identity, one alias hop")
	check(aliases.register_custom_instanced(winner,"old") and aliases.resolve("old")==winner
		and not aliases.automatically_persisted(winner),"actual lookup owner is last successful registration")
	aliases.unregister(predecessor)
	check(aliases.resolve("old")==winner and aliases.identifier_for(predecessor).is_empty(),
		"unregister displaced actor cannot erase the newer exact owner")
	check(aliases.register_custom_instanced(winner,"intermediate") and aliases.resolve("old")==null
		and aliases.resolve("intermediate")==winner and aliases.resolve("new")==winner,
		"reregistering same actor removes prior actual key before adding next")
	winner.free()
	check(aliases.resolve("new")==null,"stale weak reference never yields destroyed actor or earlier owner")
	predecessor.free()
	print("PASS PersistenceSystem primary identity: %d/%d" % [checks-failures,checks])
	quit(1 if failures else 0)
