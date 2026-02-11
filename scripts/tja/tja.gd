@icon("res://assets/editor/TJA.svg")
extends Resource
## Resource file that holds Taiko charts.
##
## Automatically applied to all [code].tja[/code] files, both in the editor
## and outside the editor via [member ResourceLoader.load]. Each chart is its own [TJAChartInfo], holding information about the current chart.
## [br] [br]
## Since this is only for the [code].tja[/code] format, this does not support osu!taiko charts as of now.
class_name TJA

## The title of this chart.
@export var title: String
## The localized title of this chart, e.g. TITLEJA:title refers to JA: title
@export var title_localized: Dictionary[String, String]
## The subtitle of this chart.
@export var subtitle: String
## The localized subtitle of this chart, e.g. TITLEJA:title refers to JA: title
@export var subtitle_localized: Dictionary[String, String]
## The creator of this chart.
@export var maker: String
## The music starting point when previewing this chart from the song select.
@export var demo_start: float = 0.0
## Base scroll multiplier.
@export var head_scroll: float = 1.0

## The start bpm.
@export var start_bpm: float = 120.0
## The offset before the first note can be registered, in seconds.
@export var offset: float = 0.0
## The music of this chart.
@export var wave: AudioStream
## The path where this TJA is located.
@export var path: String

## Music volume.
@export var song_volume: int = 100
## Sound effect volume.
@export var se_volume: int = 100

## Chart info temp values
@export var chart_meta: Dictionary[String, String]

## The individual charts.
@export var charts: Array[TJAChartInfo]
