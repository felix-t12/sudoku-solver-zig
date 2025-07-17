# Interactive Sudoku Solver

A visual Sudoku solver built with Zig and Raylib featuring:

- Interactive grid interface
- Manual number input
- Animated backtracking solver
- Adjustable solving speed
- Visual feedback for player vs solver numbers


## Algorithm
Uses a backtracking algorithm that:

- Finds all empty cells
- Tries numbers 1-9 in each cell
- Backtracks when a number violates Sudoku rules
- Continues until solution is found or proven impossible


## Controls

- **Left Click**: Select a cell
- **Right Click**: Clear a cell
- **Number Keys (1-9)**: Enter numbers
- **Backspace/Delete**: Clear selected cell
- **Solve Button**: Start automatic solving

## Dependencies

- [Zig](https://ziglang.org/) (latest stable version)
- [Raylib](https://github.com/raysan5/raylib) - A simple and easy-to-use library to enjoy videogames programming
- [Raylib-Zig](https://github.com/Not-Nik/raylib-zig) - Zig bindings for Raylib
- Raygui (included with Raylib)

## Building

```bash
# Add your build instructions here
zig build