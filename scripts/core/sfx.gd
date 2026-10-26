extends Node

## Sound effects and music by short name.

const SOUNDS := "res://assets/third_party/ninja_adventure/Audio/Sounds/"
const MUSIC := "res://assets/third_party/ninja_adventure/Audio/Musics/"

const FX := {
	"coin": "Bonus/Coin.wav",
	"gold": "Bonus/Gold1.wav",
	"buy": "Menu/Accept.wav",
	"click": "Menu/Menu5.wav",
	"cancel": "Menu/Cancel.wav",
	"hit": "Hit & Impact/Hit1.wav",
	"alert": "Alert/Alert.wav",
	"bad": "Alert/Alert3.wav",
	"dice": "Hit & Impact/Impact2.wav",
	"step": "Menu/Move1.wav",
	"wolf": "Creature/Dog.wav",
	"whoosh": "Whoosh & Slash/Whoosh.wav",
}

const SONGS := {
	"day": "36 - Village.ogg",
	"night": "9 - Quiet.ogg",
	"raid": "17 - Fight.ogg",
	"tavern": "20 - Good Time.ogg",
	"over": "7 - Sad Theme.ogg",
}

var _players: Array[AudioStreamPlayer] = []
var _music := AudioStreamPlayer.new()
var _song := ""


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6
		add_child(p)
		_players.append(p)
	_music.volume_db = -14
	add_child(_music)


func play(sound: String) -> void:
	for p in _players:
		if not p.playing:
			p.stream = load(SOUNDS + FX[sound])
			p.play()
			return


func music(song: String) -> void:
	if song == _song:
		return
	_song = song
	var s: AudioStream = load(MUSIC + SONGS[song])
	if s is AudioStreamOggVorbis:
		s.loop = true
	_music.stream = s
	_music.play()
