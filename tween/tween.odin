package tween

import "base:runtime"
import "core:mem"
import "core:math"

MAX_SEQUENCES :: 1024

Sequence :: struct {
	actions: [dynamic]Action,
	current: int,
}

Value :: union {
	Value_Type(f32),
	Value_Type(f64),
	Value_Type(f16),
	Value_Type([2]f32),
	Value_Type([3]f32),
	Value_Type([4]f32),
	Value_Type([2]f64),
	Value_Type([3]f64),
	Value_Type([4]f64),
	Value_Type([4]u8),
}

Value_Type :: struct($T: typeid) {
	value: ^T,
	start: T,
	target: T,
}

Action :: struct {
	value: Value,
	on_finished: struct {
		func: proc(data: rawptr),
		data: rawptr,
	},
	duration: f32,
	remaining: f32,
	easing: Easing,
	started: bool,
}

Easing :: enum u8 {
	Linear,
	EaseIn,
	EaseOut,
	EaseInOut,
	QuadIn,
	QuadOut,
	QuadInOut,
	ExpoIn,
	ExpoOut,
	ExpoInOut,
	BounceIn,
	BounceOut,
	BounceInOut,
	ElasticIn,
	ElasticOut,
	ElasticInOut,
	BackIn,
	BackOut,
	BackInOut,
}

tween_arena: mem.Arena
tween_alloc: runtime.Allocator

tween_sequences: [dynamic]Sequence

init :: proc(data: []u8) {
	mem.arena_init(&tween_arena, data)
	tween_alloc = mem.arena_allocator(&tween_arena)
	context.allocator = tween_alloc
	tween_sequences = make([dynamic]Sequence, 0, MAX_SEQUENCES)
}

make_sequence :: proc() -> ^Sequence {
	context.allocator = tween_alloc
	seq := Sequence {
		actions = make([dynamic]Action),
	}
	append(&tween_sequences, seq)
	return &tween_sequences[len(tween_sequences) - 1]
}

tick :: proc(dt: f32) {
	context.allocator = tween_alloc
	seq_to_delete := [MAX_SEQUENCES]int{}
	stdel_idx := 0
	for &seq, si in tween_sequences {
		act := &seq.actions[seq.current]
		if !act.started {
			act.started = true
			_set_start_value(act)	
		}
		act.remaining -= dt
		t := math.clamp(1 - act.remaining / act.duration, 0, 1)
		if act.remaining <= 0 {
			act.on_finished.func(act.on_finished.data)
			seq.current += 1
			if seq.current == len(seq.actions) {
				seq_to_delete[stdel_idx] = si
				stdel_idx += 1
				continue
			}
			next_act := &seq.actions[seq.current]
			next_act.remaining += act.remaining
		}
		switch act.easing {
		case .Linear:
			t = t
		case .EaseIn:
			t = math.cos(t * math.PI / 2)
		case .EaseOut:
			t = math.sin(t * math.PI / 2)
		case .EaseInOut:
			t = -(math.cos(t * math.PI) - 1) / 2
		case .QuadIn:
			t = t * t
		case .QuadOut:
			t = 1 - (1 - t) * (1 - t)
		case .QuadInOut:
			t = t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2
		case .ExpoIn:
			t = t == 0 ? 0 : math.pow(2, 10 * t - 10)
		case .ExpoOut:
			t = t == 1 ? 1 : 1 - math.pow(2, -10 * t)
		case .ExpoInOut:
			if t > 0 && t < 1 {
				t = t < 0.5 ? math.pow(2, 20 * t - 10) / 2 : (2 - math.pow(2, -20 * t + 10)) / 2 
			}
		case .BounceIn:
			t = 1 - _bounce_out(1 - t)
		case .BounceOut:
			t = _bounce_out(t)
		case .BounceInOut:
			t = t < 0.5 ? (1 - _bounce_out(1 - 2 * t)) / 2 : (1 + _bounce_out(2 * t - 1)) / 2
		case .ElasticIn:
			c4 :: (2 * math.PI) / 3
			if t > 0 && t < 1 {
				t = -math.pow(2, 10 * t - 10) * math.sin((t * 10 - 10.75) * c4)
			}
		case .ElasticOut:
			c4 :: (2 * math.PI) / 3
			if t > 0 && t < 1 {
				t = math.pow(2, -10 * t) * math.sin((t * 10 - 10.75) * c4)
			}
		case .ElasticInOut:
			c5 :: (2 * math.PI) / 4.5
			if t > 0 && t < 1 {
				if t < 0.5 {
				t = -(math.pow(2, 20 * t - 10) * math.sin((t * 20 - 11.125) * c5)) / 2
				}
				else {
					t = (math.pow(2, -20 * t + 10) * math.sin((t * 20 - 11.125) * c5)) / 2 + 1
				}
			}
		case .BackIn:
			c1 :: 1.70158
			c3 :: c1 + 1
			t = c3 * t * t * t - c1 * t * t
		case .BackOut:
			c1 :: 1.70158
			c3 :: c1 + 1
			t = 1 + c3 * math.pow(t - 1, 3) - c1 * math.pow(t - 1, 2)
		case .BackInOut:
			c1 :: 1.70158
			c2 :: c1 * 1.525
			t = t < 0.5 ? (math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2 : (math.pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
		}

		switch &v in act.value {
		case Value_Type(f32):
			v.value^ = math.lerp(v.start, v.target, f32(t))
		case Value_Type(f64):
			v.value^ = math.lerp(v.start, v.target, f64(t))
		case Value_Type(f16):
			v.value^ = math.lerp(v.start, v.target, f16(t))
		case Value_Type([2]f32):
			v.value^ = math.lerp(v.start, v.target, f32(t))
		case Value_Type([3]f32):
			v.value^ = math.lerp(v.start, v.target, f32(t))
		case Value_Type([4]f32):
			v.value^ = math.lerp(v.start, v.target, f32(t))
		case Value_Type([2]f64):
			v.value^ = math.lerp(v.start, v.target, f64(t))
		case Value_Type([3]f64):
			v.value^ = math.lerp(v.start, v.target, f64(t))
		case Value_Type([4]f64):
			v.value^ = math.lerp(v.start, v.target, f64(t))
		case Value_Type([4]u8):
			start := [4]f32 {
				f32(v.start.r),
				f32(v.start.g),
				f32(v.start.b),
				f32(v.start.a),
			}
			end := [4]f32 {
				f32(v.target.r),
				f32(v.target.g),
				f32(v.target.b),
				f32(v.target.a),
			}
			value := math.lerp(start, end, f32(t))
			v.value.r = u8(math.round(value.r))
			v.value.g = u8(math.round(value.g))
			v.value.b = u8(math.round(value.b))
			v.value.a = u8(math.round(value.a))
		}
	}

	for stdel_idx > 0 {
		stdel_idx -= 1
		unordered_remove(&tween_sequences, seq_to_delete[stdel_idx])
	}
}

@(private)
_bounce_out :: proc(t: f32) -> f32 {
	n1 :: 7.5625;
	d1 :: 2.75;

	x := t

	if x < 1 / d1 {
		return n1 * x * x
	} else if x < 2 / d1 {
		x -= 1.5 / d1
		return n1 * x * x + 0.75
	} else if x < 2.5 / d1 {
		x -= 2.25 / d1
		return n1 * x * x + 0.9375
	} else {
		x -= 2.625 / d1
		return n1 * x * x + 0.984375
	}
}

make_tween :: proc(val: $E/^$T, target: T, duration: f32, easing: Easing, parent_sequence: ^Sequence = nil) -> ^Action {
	context.allocator = tween_alloc

	seq := parent_sequence
	if seq == nil {
		seq = make_sequence()
	}
	append(&seq.actions, Action {
		value = Value_Type(T) {
			value = val,
			target = target,
		},
		duration = duration,
		remaining = duration,
		easing = easing,
		on_finished = {
			func = proc(_: rawptr) {},
			data = nil,
		},
	})
	return &seq.actions[len(seq.actions) - 1]
}

@(private)
_set_start_value :: proc(act: ^Action) {
	switch &v in act.value {
	case Value_Type(f32):
		v.start = v.value^
	case Value_Type(f64):
		v.start = v.value^
	case Value_Type(f16):
		v.start = v.value^
	case Value_Type([2]f32):
		v.start = v.value^
	case Value_Type([3]f32):
		v.start = v.value^
	case Value_Type([4]f32):
		v.start = v.value^
	case Value_Type([2]f64):
		v.start = v.value^
	case Value_Type([3]f64):
		v.start = v.value^
	case Value_Type([4]f64):
		v.start = v.value^
	case Value_Type([4]u8):
		v.start = v.value^
	}
}
