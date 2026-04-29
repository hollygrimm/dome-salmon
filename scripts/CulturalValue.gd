## CulturalValue.gd
## A Resource that describes a value carried by a creature or school.
## Save instances as .tres files (e.g. salmon_endurance.tres, homing.tres)
## and assign them to SalmonSchool.values in the Inspector — or pass them
## in code from Main.gd._wire_salmon_school().
##
## This file is the same template students received in their own ecosystems
## (see sp26-csat201-godot-JacobCrazyBull/scripts/CulturalValue.gd). Carrying
## the same shape into dome-salmon means student contributions can read
## authored cultural values instead of hardcoded constants.

class_name CulturalValue
extends Resource

## The name of this value (e.g. "Endurance", "Homing", "Persistence")
@export var name: String = ""

## Describe what this value means in the salmon's world — in your own words.
@export_multiline var description: String = ""

## How strongly this value pulls fish toward the school center (0.0–1.0)
@export_range(0.0, 1.0) var cohesion: float = 0.0

## How willingly fish yield space to others (0.0–1.0)
@export_range(0.0, 1.0) var generosity: float = 0.0

## How joyful or erratic the school's movement feels (0.0–1.0)
@export_range(0.0, 1.0) var playfulness: float = 0.0

## How strongly fish hold their course under pressure (0.0–1.0)
@export_range(0.0, 1.0) var persistence: float = 0.0

## How cautiously fish move through their environment (0.0–1.0)
@export_range(0.0, 1.0) var restraint: float = 0.0

## How strongly fish tend to one another / hold longer in WANDER (0.0–1.0)
@export_range(0.0, 1.0) var care: float = 0.0
