class_name Furnishing
extends RefCounted
## Buy/sell furniture with validation and an undo/redo history that covers both furniture and funds.
## Every operation is all-or-nothing: if validation fails, nothing (money, furniture, history) changes.

var sim: Simulation
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []

func _init(s: Simulation) -> void:
	sim = s

func _lot_id() -> String: return String(sim.state["active_lot"])

## Returns {ok, reason}. ignore_id lets an item be re-validated in place.
func can_place(item: String, cell: Vector2i, rot: int, ignore_id: String = "") -> Dictionary:
	if not Catalog.has(item): return {"ok": false, "reason": "Unknown item."}
	var lid := _lot_id()
	var lay := sim.layout_id(lid)
	var def := Catalog.get_def(item)
	var is_floor: bool = def["layer"] == "floor"
	var clear := LotLayouts.keep_clear(lay, sim.lot(lid).get("structure", {}))
	var mine := Catalog.cells(item, cell, rot)
	for c in mine:
		var t := sim.tile(lid, c)
		if t == "X": return {"ok": false, "reason": "Outside the lot."}
		if LotLayouts.is_structural_block(t): return {"ok": false, "reason": "Blocked by a wall or garden bed."}
		if not is_floor and clear.has(c): return {"ok": false, "reason": "Keep doorways and the gate clear."}
	var occupied := {}
	for fid in sim.furniture(lid):
		if fid == ignore_id: continue
		var f: Dictionary = sim.furniture(lid)[fid]
		var fl: bool = Catalog.get_def(f["item"])["layer"] == "floor"
		if fl != is_floor: continue   # rugs sit under furniture
		for c in Catalog.cells(f["item"], GameState.cell_of(f["cell"]), int(f["rot"])): occupied[c] = Catalog.get_def(f["item"])["name"]
	for c in mine:
		if occupied.has(c): return {"ok": false, "reason": "Overlaps the %s." % occupied[c]}
	if not is_floor:
		for ch in sim.chars_on(lid):
			if mine.has(GameState.cell_of(ch["cell"])): return {"ok": false, "reason": "%s is standing there." % ch["name"]}
	var slots: Array = def["slots"]
	if not slots.is_empty():
		var ok := false
		for sl in slots:
			for cand in sl["approach"]:
				var ap := Catalog.local_cell_to_world(item, cell, rot, cand)
				var t := sim.tile(lid, ap)
				if t != "X" and not LotLayouts.is_structural_block(t) and not occupied.has(ap) and not mine.has(ap): ok = true
		if not ok: return {"ok": false, "reason": "Nobody could reach it there — leave room in front."}
	return {"ok": true, "reason": ""}

func buy(item: String, cell: Vector2i, rot: int) -> Dictionary:
	var v := can_place(item, cell, rot)
	if not v["ok"]: return v
	var price: int = Catalog.get_def(item)["price"]
	if sim.funds() < price: return {"ok": false, "reason": "Not enough funds (need %s)." % Catalog.format_cents(price)}
	var rec := {"id": GameState.new_id(sim.state, "f"), "item": item, "cell": [cell.x, cell.y], "rot": rot}
	_add(rec, -price)
	undo_stack.append({"op": "buy", "rec": rec.duplicate(true), "cents": price})
	redo_stack.clear()
	return {"ok": true, "reason": "", "id": rec["id"]}

func sell(fid: String) -> Dictionary:
	var lid := _lot_id()
	if not sim.furniture(lid).has(fid): return {"ok": false, "reason": "Nothing to sell."}
	var rec: Dictionary = sim.furniture(lid)[fid].duplicate(true)
	var price: int = Catalog.get_def(rec["item"])["price"]
	_remove(fid, price)
	undo_stack.append({"op": "sell", "rec": rec, "cents": price})
	redo_stack.clear()
	return {"ok": true, "reason": ""}

## Plan a single cell or a two-cell door/window, using integer cents throughout.
func plan_structure(tool: String, cell: Vector2i, vertical: bool) -> Dictionary:
	if not STRUCTURE.has(tool):
		return {"ok": false, "reason": "Choose a building tool."}
	var lid := _lot_id()
	var before := {}
	var after := {}
	var tile := sim.tile(lid, cell)
	var target: String = STRUCTURE[tool]["tile"]
	var cells: Array[Vector2i] = [cell]
	if LotLayouts.is_opening(target):
		cells.append(cell + (Vector2i.DOWN if vertical else Vector2i.RIGHT))
	elif tool == "erase" and LotLayouts.is_opening(tile):
		for offset in NEIGHBORS:
			if sim.tile(lid, cell + offset) == tile:
				cells.append(cell + offset)
				break
	for c in cells:
		var old := sim.tile(lid, c)
		if not Rect2i(1, 1, LotLayouts.SIZE - 2, LotLayouts.SIZE - 2).has_point(c) or old not in [" ", ".", "t", "#", "D", "W"]:
			return {"ok": false, "reason": "Paths, gardens and the lot boundary are protected."}
		if LotLayouts.is_opening(old) and tool != "erase":
			return {"ok": false, "reason": "Remove the existing opening first."}
		if target == "." and old == "#":
			return {"ok": false, "reason": "Remove the wall before laying a floor."}
		if LotLayouts.is_opening(target):
			for offset in NEIGHBORS:
				if not cells.has(c + offset) and sim.tile(lid, c + offset) == target:
					return {"ok": false, "reason": "Leave a cell between matching openings."}
		if old != target:
			before[c] = old
			after[c] = target
	if after.is_empty():
		return {"ok": false, "reason": "This area already matches the selected tool."}
	var cents: int = STRUCTURE[tool]["price"]
	var result := _check_structure(after, cents)
	result.merge({"op": "structure", "before": before, "after": after, "cents": cents, "cells": cells})
	return result

const NEIGHBORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const STRUCTURE := {
	"wall": {"name": "Stucco wall", "tile": "#", "price": 3500},
	"door": {"name": "Door", "tile": "D", "price": 9000},
	"window": {"name": "Window", "tile": "W", "price": 7500},
	"floor": {"name": "Walnut floor", "tile": ".", "price": 1200},
	"erase": {"name": "Remove", "tile": " ", "price": 0},
}

func edit_structure(tool: String, cell: Vector2i, vertical: bool) -> Dictionary:
	var cmd := plan_structure(tool, cell, vertical)
	if not cmd["ok"]:
		return cmd
	_set_structure(cmd["after"], cmd["cents"])
	undo_stack.append(cmd)
	redo_stack.clear()
	return cmd

func _check_structure(tiles: Dictionary, cents: int) -> Dictionary:
	if sim.funds() < cents:
		return {"ok": false, "reason": "Not enough funds."}
	var lid := _lot_id()
	var proposed: Dictionary = sim.lot(lid).get("structure", {}).duplicate()
	for c in tiles:
		proposed[LotLayouts.cell_key(c)] = tiles[c]
	var protected := LotLayouts.keep_clear(sim.layout_id(lid), proposed)
	var occupied := {}
	for rec in sim.furniture(lid).values():
		for c in Catalog.cells(rec["item"], GameState.cell_of(rec["cell"]), int(rec["rot"])):
			occupied[c] = true
	for c in tiles:
		if LotLayouts.is_structural_block(tiles[c]):
			if occupied.has(c):
				return {"ok": false, "reason": "Move the furniture out of the way first."}
			if protected.has(c) and not LotLayouts.is_structural_block(sim.tile(lid, c)):
				return {"ok": false, "reason": "Keep doorways and the lot entrance clear."}
			for person in sim.chars_on(lid):
				if GameState.cell_of(person["cell"]) == c:
					return {"ok": false, "reason": "%s is standing there." % person["name"]}
		if tiles[c] == "D":
			if occupied.has(c):
				return {"ok": false, "reason": "Clear furniture from the doorway."}
			for offset in NEIGHBORS:
				if occupied.has(c + offset):
					return {"ok": false, "reason": "Clear furniture beside the doorway."}
	return {"ok": true, "reason": ""}

func _set_structure(tiles: Dictionary, cents: int) -> void:
	var lid := _lot_id()
	var lot := sim.lot(lid)
	var edits: Dictionary = lot.get("structure", {})
	for c in tiles:
		var key := LotLayouts.cell_key(c)
		if tiles[c] == LotLayouts.tile(sim.layout_id(lid), c):
			edits.erase(key)
		else:
			edits[key] = tiles[c]
	if edits.is_empty():
		lot.erase("structure")
	else:
		lot["structure"] = edits
	sim.household()["funds"] = sim.funds() - cents
	sim.rebuild_nav(lid)

func undo() -> Dictionary:
	if undo_stack.is_empty(): return {"ok": false, "reason": "Nothing to undo."}
	var cmd: Dictionary = undo_stack[-1]
	var r := _apply(cmd, true)
	if r["ok"]: redo_stack.append(undo_stack.pop_back())
	return r

func redo() -> Dictionary:
	if redo_stack.is_empty(): return {"ok": false, "reason": "Nothing to redo."}
	var cmd: Dictionary = redo_stack[-1]
	var r := _apply(cmd, false)
	if r["ok"]: undo_stack.append(redo_stack.pop_back())
	return r

## inverse=true undoes cmd. A buy's inverse removes+refunds; a sell's inverse re-adds+charges.
func _apply(cmd: Dictionary, inverse: bool) -> Dictionary:
	if cmd["op"] == "structure":
		var tiles: Dictionary = cmd["before"] if inverse else cmd["after"]
		var cost := int(cmd["cents"]) * (-1 if inverse else 1)
		var result := _check_structure(tiles, cost)
		if result["ok"]:
			_set_structure(tiles, cost)
			result["op"] = "structure"
		return result
	var rec: Dictionary = cmd["rec"]
	var adding: bool = (cmd["op"] == "buy") != inverse
	if adding:
		var v := can_place(rec["item"], GameState.cell_of(rec["cell"]), int(rec["rot"]))
		if not v["ok"]: return v
		if sim.funds() < int(cmd["cents"]): return {"ok": false, "reason": "Not enough funds to restore that."}
		_add(rec.duplicate(true), -int(cmd["cents"]))
	else:
		if not sim.furniture(_lot_id()).has(rec["id"]): return {"ok": false, "reason": "That item no longer exists."}
		_remove(rec["id"], int(cmd["cents"]))
	return {"ok": true, "reason": ""}

func _add(rec: Dictionary, delta: int) -> void:
	var lid := _lot_id()
	sim.furniture(lid)[rec["id"]] = rec
	sim.household()["funds"] = sim.funds() + delta
	sim.rebuild_nav(lid)

func _remove(fid: String, delta: int) -> void:
	var lid := _lot_id()
	sim.furniture(lid).erase(fid)
	sim.household()["funds"] = sim.funds() + delta
	sim.on_furniture_removed(lid, fid)
