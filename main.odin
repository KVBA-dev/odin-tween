package main

import rl "vendor:raylib"
import "tween"
import "core:mem"

main :: proc() {
	rl.InitWindow(1280, 768, "tween")
	defer rl.CloseWindow()


	tween_data := make([]u8, mem.Megabyte)
	defer delete(tween_data)
	tween.init(tween_data)
	
	dt: f32

	target: rl.Vector2 = 50

	color := rl.LIME
	pos: f32 = 50
	start_anim(&color, &pos)
	
	for !rl.WindowShouldClose() {
		dt = rl.GetFrameTime()
		if rl.IsMouseButtonPressed(.LEFT) {
			tween.make_tween(&target, rl.GetMousePosition(), 0.5, .BounceOut, nil)
		}
		
		if rl.IsKeyPressed(.SPACE) {
			start_anim(&color, &pos)
		}

		tween.tick(dt)
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)
		rl.DrawCircle(i32(target.x), i32(target.y), 30, rl.RED)
		rl.DrawCircle(i32(pos), 500, 30, color)
		rl.EndDrawing()
	}
}

start_anim :: proc(color: ^rl.Color, pos: ^f32) {
	pos^ = 50
	color^ = rl.LIME
	seq := tween.make_sequence()
	tween.make_tween(pos, 200, 1, .BounceOut, seq)
	tween.make_tween(color, rl.SKYBLUE, 1, .QuadOut, seq)
	tween.make_tween(pos, 50, 1, .BackInOut, seq)
}
