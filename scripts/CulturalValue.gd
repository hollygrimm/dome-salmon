## CulturalValue.gd
## A Resource that describes a value carried by a creature.
## Save instances as .tres files (e.g. reciprocity.tres, humor.tres)
## and assign them to creatures in the Inspector.
##
## Students: copy this file into your own project's scripts/ folder.
## Rename the exported fields to match the values in YOUR ecosystem.

class_name CulturalValue
extends Resource

## The name of this value (e.g. "Reciprocity", "Humor", "Endurance")
@export var name: String = ""

## Describe what this value means in your world — in your own words.
@export_multiline var description: String = ""

## How strongly this value pulls the creature toward others (0.0–1.0)
@export_range(0.0, 1.0) var cohesion: float = 0.0

## How willingly this creature yields space to others (0.0–1.0)
@export_range(0.0, 1.0) var generosity: float = 0.0

## How joyful or erratic the creature's movement feels (0.0–1.0)
@export_range(0.0, 1.0) var playfulness: float = 0.0

## How strongly the creature holds its course under pressure (0.0–1.0)
@export_range(0.0, 1.0) var persistence: float = 0.0

## How cautiously the creature moves through its environment (0.0–1.0)
@export_range(0.0, 1.0) var restraint: float = 0.0
