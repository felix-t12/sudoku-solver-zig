const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");

const Vector2 = rl.Vector2;

const GAP = 40;
const THICKNESS = 2;
const SIZE = GAP * 9;
const STARTING_X = 100;
const STARTING_Y = 100;

const Solver = struct {
    curr_i: usize,
    idxs: std.ArrayList(usize),
};

const State = struct {
    board: [81]u8,
    hover_index: usize,
    selected_index: usize,
    mouse_point: Vector2,
    solve_button: rl.Rectangle,
    solving: bool = false,
    legal: bool = true,
    change_bitset: std.bit_set.IntegerBitSet(81),
    allocator: std.mem.Allocator,
    solver: Solver,
    time_between_steps: f32,
    time_since_step: f32,
    steps_per_frame: u16,
};

var state: State = undefined;

fn draw_grid() void {
    //draw horizontal lines
    for (0..10) |i| {
        rl.drawLineEx(
            Vector2.init(
                STARTING_X,
                STARTING_Y + @as(f32, @floatFromInt(i)) * GAP,
            ),
            Vector2.init(
                STARTING_X + SIZE,
                STARTING_Y + @as(f32, @floatFromInt(i)) * GAP,
            ),
            if (i % 3 == 0) THICKNESS * 2 else THICKNESS,
            .light_gray,
        );
    }
    //draw vertical lines

    for (0..10) |i| {
        rl.drawLineEx(
            Vector2.init(
                STARTING_X + @as(f32, @floatFromInt(i)) * GAP,
                STARTING_Y,
            ),
            Vector2.init(
                STARTING_X + @as(f32, @floatFromInt(i)) * GAP,
                STARTING_Y + SIZE,
            ),
            if (i % 3 == 0) THICKNESS * 2 else THICKNESS,
            .light_gray,
        );
    }
}

fn draw_numbers() void {
    for (state.board, 0..) |num, idx| {
        const col = @as(i32, @intCast(idx % 9));
        const row = @as(i32, @intCast(idx / 9));
        const text = rl.textFormat("%u", .{num});
        const text_height = 25;
        const text_width = @as(u8, @intCast(rl.measureText(
            text,
            text_height,
        )));

        const player_placed = !state.change_bitset.isSet(idx);

        if (num != 0 or state.hover_index == idx or state.selected_index == idx) {
            rl.drawText(
                rl.textFormat("%u", .{num}),
                STARTING_X + col * GAP + GAP / 2 - text_width / 2,
                STARTING_Y + row * GAP + GAP / 2 - text_height / 2,
                text_height,
                if (state.selected_index == idx) .red else (if (player_placed) .blue else .gray),
            );
        }
    }
}

fn world_to_grid(x: f32, y: f32) ?usize {
    if (x < STARTING_X or y < STARTING_Y or
        x > STARTING_X + 9 * GAP or y > STARTING_Y + 9 * GAP)
        return null;

    const new_x = x - STARTING_X;
    const new_y = y - STARTING_Y;
    const col = @as(usize, @intFromFloat(new_x / GAP));
    const row = @as(usize, @intFromFloat(new_y / GAP));
    return row * 9 + col;
}

fn input_handling() !void {
    if (state.solving) {
        return; // not anything sudoku related while solving
    }
    if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
        const idx = world_to_grid(state.mouse_point.x, state.mouse_point.y);
        if (idx) |value|
            state.selected_index = value;

        if (rl.checkCollisionPointRec(state.mouse_point, state.solve_button)) {
            try solve();
        }
    } else if (rl.isMouseButtonPressed(rl.MouseButton.right)) {
        const num = &state.board[state.hover_index];
        num.* = 0;
    }

    for (1..10) |key| {
        const zero = @intFromEnum(rl.KeyboardKey.zero);
        if (rl.isKeyPressed(@enumFromInt(zero + @as(i32, @intCast(key))))) {
            const num = &state.board[state.selected_index];
            num.* = @as(u8, @intCast(key));
        }
    }
}

fn solve() !void {
    std.debug.print("SOLVE\n", .{});
    check();
    if (!state.legal)
        return;

    state.change_bitset = .initEmpty();
    for (state.board, 0..) |num, idx| {
        state.change_bitset.setValue(idx, num == 0);
    }

    var iter = state.change_bitset.iterator(.{});
    state.solver.idxs.clearRetainingCapacity();
    while (iter.next()) |idx| {
        try state.solver.idxs.append(idx);
    }
    std.debug.print("{} unsolved places\n", .{state.solver.idxs.items.len});
    state.solver.curr_i = 0;
    std.debug.assert((state.change_bitset.count() == state.solver.idxs.items.len));

    if (state.solver.idxs.items.len == 0) {
        return;
    } else state.solving = true;
}

fn solve_step() !void {
    const i = &state.solver.curr_i;
    const max_i = state.solver.idxs.items.len - 1;

    //std.debug.print("solve step\n", .{});

    if (i.* > max_i) {
        state.solving = false;
        return;
    }

    const curr_idx = state.solver.idxs.items[state.solver.curr_i];

    if (state.board[curr_idx] == 9) {
        state.board[curr_idx] = 0;
        state.solver.curr_i -= 1;
    } else {
        state.board[curr_idx] += 1;
        check();
    }
    if (state.legal) {
        state.solver.curr_i += 1;
    }
}

fn check() void {
    const b = &state.board;

    for (0..9) |i| {
        const row = b.*[9 * i .. 9 * i + 9];

        var seen: std.bit_set.IntegerBitSet(10) = .initEmpty();

        for (row) |num| {
            if (num == 0) continue;
            const idx = @as(usize, @intCast(num));
            if (seen.isSet(idx)) {
                state.legal = false;
                return;
            } else {
                seen.set(idx);
            }
        }

        const col = [9]u8{
            b.*[i + 9 * 0],
            b.*[i + 9 * 1],
            b.*[i + 9 * 2],
            b.*[i + 9 * 3],
            b.*[i + 9 * 4],
            b.*[i + 9 * 5],
            b.*[i + 9 * 6],
            b.*[i + 9 * 7],
            b.*[i + 9 * 8],
        };

        seen = .initEmpty();

        for (col) |num| {
            if (num == 0) continue;
            const idx = @as(usize, @intCast(num));
            if (seen.isSet(idx)) {
                state.legal = false;
                //std.debug.print("illegal col {}:  {any}\n", .{ i, col });
                return;
            } else {
                seen.set(idx);
            }
        }

        const b_start = (i / 3) * 9 * 3 + i % 3 * 3;

        const block = [9]u8{
            b.*[b_start + 0 + 0],  b.*[b_start + 0 + 1],  b.*[b_start + 0 + 2],
            b.*[b_start + 9 + 0],  b.*[b_start + 9 + 1],  b.*[b_start + 9 + 2],
            b.*[b_start + 18 + 0], b.*[b_start + 18 + 1], b.*[b_start + 18 + 2],
        };

        seen = .initEmpty();

        for (block) |num| {
            if (num == 0) continue;
            const idx = @as(usize, @intCast(num));
            if (seen.isSet(idx)) {
                state.legal = false;
                //std.debug.print("illegal block {}:  {any}\n", .{ i, block });
                return;
            } else {
                seen.set(idx);
            }
        }

        state.legal = true;
    }
}

pub fn main() anyerror!void {
    var slider_val: f32 = 0;
    rl.initWindow(800, 600, "Sudoku Solver");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    state.allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    state.board = .{0} ** 81;
    state.solving = false;
    state.legal = true;
    state.change_bitset = .initEmpty();
    state.time_between_steps = 0.001;
    state.time_since_step = 0;
    state.steps_per_frame = 500;

    state.solver.idxs = std.ArrayList(usize).init(state.allocator);
    defer state.solver.idxs.deinit();

    state.mouse_point = Vector2.init(0, 0);

    state.solve_button = rl.Rectangle.init(600, 300, 110, 50);

    while (!rl.windowShouldClose()) {
        const delta = rl.getFrameTime();
        state.mouse_point = rl.getMousePosition();
        const idx = world_to_grid(state.mouse_point.x, state.mouse_point.y);
        if (idx) |value|
            state.hover_index = value;

        if (state.solving) {
            if (state.time_since_step >= state.time_between_steps) {
                for (0..state.steps_per_frame) |_|
                    try solve_step();
                state.time_since_step = 0;
            } else state.time_since_step += delta;
        }

        try input_handling();

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);

        draw_grid();
        draw_numbers();
        const minp = 0;
        const maxp = 100;

        _ = rg.slider(
            rl.Rectangle.init(520, 100, 200, 40),
            "1 iteration",
            "10000 iterations",
            &slider_val,
            minp,
            maxp,
        );

        const minv = std.math.log(f32, std.math.e, 1);
        const maxv = std.math.log(f32, std.math.e, 10000);

        // calculate adjustment factor
        const scale = (maxv - minv) / (maxp - minp);

        const log_val = std.math.exp(minv + scale * (slider_val - minp));
        state.steps_per_frame = @as(u16, @intFromFloat(log_val));

        rl.drawText(
            rl.textFormat("%d steps", .{state.steps_per_frame}),
            600,
            200,
            20,
            .light_gray,
        );

        rl.drawRectangleLinesEx(
            state.solve_button,
            3,
            if (state.solving) .red else .light_gray,
        );
        rl.drawText(
            "Solve!",
            610,
            310,
            30,
            if (state.solving) .red else .gray,
        );

        rl.drawText(
            "Sudoku Solver",
            100,
            20,
            20,
            .light_gray,
        );
    }
}
